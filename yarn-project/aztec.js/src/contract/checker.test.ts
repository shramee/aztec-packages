import { abiChecker } from './checker.js';

describe('abiChecker', () => {
  let abi: any;

  it('should throw an error if it has no functions', () => {
    abi = {
      name: 'TEST_ABI',
    };
    expect(() => abiChecker(abi)).toThrow('artifact has no functions');
    abi = {
      name: 'TEST_ABI',
      functions: [],
    };
    expect(() => abiChecker(abi)).toThrow('artifact has no functions');
  });

  it('should error if ABI has no names', () => {
    abi = {
      name: 'TEST_ABI',
      functions: [{ bytecode: '0af', parameters: [{ type: { kind: 'test' } }] }],
    };
    expect(() => abiChecker(abi)).toThrow('ABI function has no name');
  });

  it('should error if ABI function has unrecognized type', () => {
    abi = {
      name: 'TEST_ABI',
      functions: [
        {
          name: 'Function name',
          bytecode: '0af',
          parameters: [{ type: { kind: 'test' } }],
        },
      ],
    };
    expect(() => abiChecker(abi)).toThrow('ABI function parameter has an unrecognized type');
  });

  it('should error if integer is incorrectly formed', () => {
    abi = {
      name: 'TEST_ABI',
      functions: [
        {
          name: 'constructor',
          bytecode: '0af',
          parameters: [{ type: { kind: 'integer', sign: 5 } }],
        },
      ],
    };
    expect(() => abiChecker(abi)).toThrow('Unrecognized attribute on type integer');
  });

  it('should error if string is incorrectly formed', () => {
    abi = {
      name: 'TEST_ABI',
      functions: [
        {
          name: 'constructor',
          bytecode: '0af',
          parameters: [{ type: { kind: 'string', sign: 5, additionalParam: true } }],
        },
      ],
    };
    expect(() => abiChecker(abi)).toThrow('Unrecognized attribute on type string');
  });

  it('should error if struct is incorrectly formed', () => {
    abi = {
      name: 'TEST_ABI',
      functions: [
        {
          name: 'constructor',
          bytecode: '0af',
          parameters: [
            {
              type: {
                kind: 'struct',
              },
            },
          ],
        },
      ],
    };
    expect(() => abiChecker(abi)).toThrow('Unrecognized attribute on type struct');
  });

  it('should error if array is incorrectly formed', () => {
    abi = {
      name: 'TEST_ABI',
      functions: [
        {
          name: 'constructor',
          bytecode: '0af',
          parameters: [
            {
              type: {
                kind: 'array',
                length: 5,
                type: {
                  kind: 'array',
                  length: '5',
                  type: {
                    sign: 'value',
                    width: 5,
                    kind: 'integer',
                  },
                },
              },
            },
          ],
        },
      ],
    };
    expect(() => abiChecker(abi)).toThrow('ABI function parameter has an incorrectly formed array');
  });

  it('valid matrix should pass checker', () => {
    abi = {
      name: 'TEST_ABI',
      functions: [
        {
          name: 'constructor',
          bytecode: '0af',
          parameters: [
            {
              type: {
                kind: 'array',
                length: 5,
                type: {
                  kind: 'array',
                  length: 5,
                  type: {
                    sign: 'value',
                    width: 5,
                    kind: 'integer',
                  },
                },
              },
            },
          ],
          isInitializer: true,
        },
      ],
    };
    expect(abiChecker(abi)).toBe(true);
  });

  it('valid struct should pass checker', () => {
    abi = {
      name: 'TEST_ABI',
      functions: [
        {
          name: 'constructor',
          bytecode: '0af',
          parameters: [
            {
              type: {
                kind: 'struct',
                path: 'mystruct',
                fields: [
                  {
                    name: 'name',
                    type: {
                      sign: 'value',
                      width: 5,
                      kind: 'integer',
                    },
                  },
                ],
              },
            },
          ],
          isInitializer: true,
        },
      ],
    };
    expect(abiChecker(abi)).toBe(true);
  });
});
