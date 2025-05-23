use crate::{
    context::{PrivateContext, PublicContext, UtilityContext},
    state_vars::shared_mutable::SharedMutable,
    test::{helpers::test_environment::TestEnvironment, mocks::mock_struct::MockStruct},
};
use protocol_types::traits::Empty;

use dep::std::mem::zeroed;

global new_value: MockStruct = MockStruct { a: 17, b: 42 };

global new_delay: u32 = 20;

global storage_slot: Field = 47;

global TEST_INITIAL_DELAY: u32 = 32;

unconstrained fn setup() -> TestEnvironment {
    TestEnvironment::new()
}

unconstrained fn in_public(
    env: TestEnvironment,
) -> SharedMutable<MockStruct, TEST_INITIAL_DELAY, &mut PublicContext> {
    SharedMutable::new(&mut env.public(), storage_slot)
}

unconstrained fn in_private(
    env: &mut TestEnvironment,
    historical_block_number: u32,
) -> SharedMutable<MockStruct, TEST_INITIAL_DELAY, &mut PrivateContext> {
    SharedMutable::new(&mut env.private_at(historical_block_number), storage_slot)
}

unconstrained fn in_utility(
    env: TestEnvironment,
) -> SharedMutable<MockStruct, TEST_INITIAL_DELAY, UtilityContext> {
    SharedMutable::new(env.utility(), storage_slot)
}

#[test]
unconstrained fn test_get_current_value_in_public_initial() {
    let env = setup();
    let state_var = in_public(env);

    assert_eq(state_var.get_current_value(), zeroed());
}

#[test]
unconstrained fn test_get_scheduled_value_in_public() {
    let mut env = setup();
    let state_var = in_public(env);

    // Schedule a value change that will activate at `public_context.block_number() + current_delay`.
    // Since we haven't modified the delay, it remains at the initial value of TEST_INITIAL_DELAY.
    state_var.schedule_value_change(new_value);

    let (scheduled, block_of_change) = state_var.get_scheduled_value();
    assert_eq(scheduled, new_value);

    // The block of change should equal the pending block number plus TEST_INITIAL_DELAY because:
    // 1. The value change is scheduled using the block number from the public context
    // 2. The public context's block number corresponds to the pending block
    // 3. The current delay is TEST_INITIAL_DELAY since it hasn't been modified
    assert_eq(block_of_change, env.pending_block_number() + TEST_INITIAL_DELAY);
}

#[test]
unconstrained fn test_get_current_value_in_public_before_scheduled_change() {
    let mut env = setup();
    let state_var = in_public(env);

    state_var.schedule_value_change(new_value);

    let (_, block_of_change) = state_var.get_scheduled_value();

    let original_value = zeroed();

    // The current value has not changed
    assert_eq(state_var.get_current_value(), original_value);

    // The current value still does not change right before the block of change
    env.advance_block_to(block_of_change - 1);
    assert_eq(state_var.get_current_value(), original_value);
}

#[test]
unconstrained fn test_get_current_value_in_public_at_scheduled_change() {
    let mut env = setup();
    let state_var = in_public(env);

    state_var.schedule_value_change(new_value);

    let (_, block_of_change) = state_var.get_scheduled_value();

    env.advance_block_to(block_of_change);
    assert_eq(state_var.get_current_value(), new_value);
}

#[test]
unconstrained fn test_get_current_value_in_public_after_scheduled_change() {
    let mut env = setup();
    let state_var = in_public(env);

    state_var.schedule_value_change(new_value);

    let (_, block_of_change) = state_var.get_scheduled_value();

    env.advance_block_to(block_of_change + 10);
    assert_eq(state_var.get_current_value(), new_value);
}

#[test]
unconstrained fn test_get_current_delay_in_public_initial() {
    let env = setup();
    let state_var = in_public(env);

    assert_eq(state_var.get_current_delay(), TEST_INITIAL_DELAY);
}

#[test]
unconstrained fn test_get_scheduled_delay_in_public() {
    let mut env = setup();
    let state_var = in_public(env);

    state_var.schedule_delay_change(new_delay);

    let (scheduled, block_of_change) = state_var.get_scheduled_delay();
    assert_eq(scheduled, new_delay);
    // The new delay is smaller, therefore we need to wait for the difference between current and new
    assert_eq(block_of_change, env.pending_block_number() + TEST_INITIAL_DELAY - new_delay);
}

#[test]
unconstrained fn test_get_current_delay_in_public_before_scheduled_change() {
    let mut env = setup();
    let state_var = in_public(env);

    state_var.schedule_delay_change(new_delay);

    let (_, block_of_change) = state_var.get_scheduled_delay();

    let original_delay = TEST_INITIAL_DELAY;

    // The current delay has not changed
    assert_eq(state_var.get_current_delay(), original_delay);

    // The current delay still does not change right before the block of change
    env.advance_block_to(block_of_change - 1);
    assert_eq(state_var.get_current_delay(), original_delay);
}

#[test]
unconstrained fn test_get_current_delay_in_public_at_scheduled_change() {
    let mut env = setup();
    let state_var = in_public(env);

    state_var.schedule_delay_change(new_delay);

    let (_, block_of_change) = state_var.get_scheduled_delay();

    env.advance_block_to(block_of_change);
    assert_eq(state_var.get_current_delay(), new_delay);
}

#[test]
unconstrained fn test_get_current_delay_in_public_after_scheduled_change() {
    let mut env = setup();
    let state_var = in_public(env);

    state_var.schedule_delay_change(new_delay);

    let (_, block_of_change) = state_var.get_scheduled_delay();

    env.advance_block_to(block_of_change + 10);
    assert_eq(state_var.get_current_delay(), new_delay);
}

#[test]
unconstrained fn test_get_current_value_in_private_initial() {
    let mut env = setup();

    let historical_block_number = env.pending_block_number();
    let state_var = in_private(&mut env, historical_block_number);

    assert_eq(state_var.get_current_value(), zeroed());
    assert_eq(
        state_var.context.max_block_number.unwrap(),
        historical_block_number + TEST_INITIAL_DELAY,
    );
}

#[test]
unconstrained fn test_get_current_value_in_private_before_change() {
    let mut env = setup();

    let public_state_var = in_public(env);
    public_state_var.schedule_value_change(new_value);

    let (_, block_of_change) = public_state_var.get_scheduled_value();

    let schedule_block_number = env.pending_block_number();

    let private_state_var = in_private(&mut env, schedule_block_number);
    assert_eq(private_state_var.get_current_value(), MockStruct::empty());
    assert_eq(private_state_var.context.max_block_number.unwrap(), block_of_change - 1);
}

#[test]
unconstrained fn test_get_current_value_in_private_immediately_before_change() {
    let mut env = setup();

    let public_state_var = in_public(env);
    public_state_var.schedule_value_change(new_value);

    let (_, block_of_change) = public_state_var.get_scheduled_value();

    let private_state_var = in_private(&mut env, block_of_change - 1);

    // Note that this transaction would never be valid since the max block number is the same as the historical block
    // used to built the proof, i.e. in the past.
    assert_eq(private_state_var.get_current_value(), MockStruct::empty());
    assert_eq(private_state_var.context.max_block_number.unwrap(), block_of_change - 1);
}

#[test]
unconstrained fn test_get_current_value_in_private_at_change() {
    let mut env = setup();

    let public_state_var = in_public(env);
    public_state_var.schedule_value_change(new_value);

    let (_, block_of_change) = public_state_var.get_scheduled_value();

    let historical_block_number = block_of_change;
    let private_state_var = in_private(&mut env, historical_block_number);
    assert_eq(private_state_var.get_current_value(), new_value);
    assert_eq(
        private_state_var.context.max_block_number.unwrap(),
        historical_block_number + TEST_INITIAL_DELAY,
    );
}

#[test]
unconstrained fn test_get_current_value_in_private_after_change() {
    let mut env = setup();

    let public_state_var = in_public(env);
    public_state_var.schedule_value_change(new_value);

    let (_, block_of_change) = public_state_var.get_scheduled_value();

    let historical_block_number = block_of_change + 10;
    let private_state_var = in_private(&mut env, historical_block_number);
    assert_eq(private_state_var.get_current_value(), new_value);
    assert_eq(
        private_state_var.context.max_block_number.unwrap(),
        historical_block_number + TEST_INITIAL_DELAY,
    );
}

#[test]
unconstrained fn test_get_current_value_in_private_with_non_initial_delay() {
    let mut env = setup();

    let public_state_var = in_public(env);
    public_state_var.schedule_value_change(new_value);
    public_state_var.schedule_delay_change(new_delay);

    let (_, value_block_of_change) = public_state_var.get_scheduled_value();
    let (_, delay_block_of_change) = public_state_var.get_scheduled_delay();

    let historical_block_number = if value_block_of_change > delay_block_of_change {
        value_block_of_change
    } else {
        delay_block_of_change
    };

    let private_state_var = in_private(&mut env, historical_block_number);
    assert_eq(private_state_var.get_current_value(), new_value);
    assert_eq(
        private_state_var.context.max_block_number.unwrap(),
        historical_block_number + new_delay,
    );
}

#[test]
unconstrained fn test_get_current_value_in_utility_initial() {
    let env = setup();
    let state_var = in_utility(env);

    assert_eq(state_var.get_current_value(), zeroed());
}

#[test]
unconstrained fn test_get_current_value_in_utility_before_scheduled_change() {
    let mut env = setup();
    let state_var_public = in_public(env);

    state_var_public.schedule_value_change(new_value);

    let (_, block_of_change) = state_var_public.get_scheduled_value();

    let original_value = zeroed();

    let mut state_var_unconstrained = in_utility(env);

    // The current value has not changed
    assert_eq(state_var_unconstrained.get_current_value(), original_value);

    // The current value still does not change right before the block of change
    env.advance_block_to(block_of_change - 1);

    state_var_unconstrained = in_utility(env);
    assert_eq(state_var_unconstrained.get_current_value(), original_value);
}

#[test]
unconstrained fn test_get_current_value_in_utility_at_scheduled_change() {
    let mut env = setup();
    let state_var_public = in_public(env);

    state_var_public.schedule_value_change(new_value);

    let (_, block_of_change) = state_var_public.get_scheduled_value();

    env.advance_block_to(block_of_change);

    let state_var_unconstrained = in_utility(env);
    assert_eq(state_var_unconstrained.get_current_value(), new_value);
}

#[test]
unconstrained fn test_get_current_value_in_utility_after_scheduled_change() {
    let mut env = setup();
    let state_var_public = in_public(env);

    state_var_public.schedule_value_change(new_value);

    let (_, block_of_change) = state_var_public.get_scheduled_value();

    env.advance_block_to(block_of_change + 10);
    let state_var_unconstrained = in_utility(env);
    assert_eq(state_var_unconstrained.get_current_value(), new_value);
}
