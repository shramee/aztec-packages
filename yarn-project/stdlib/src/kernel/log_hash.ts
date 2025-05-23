import { Fr } from '@aztec/foundation/fields';
import { BufferReader, FieldReader, serializeToBuffer } from '@aztec/foundation/serialize';

import { inspect } from 'util';

import { AztecAddress } from '../aztec-address/index.js';
import type { Ordered } from './utils/interfaces.js';

export class LogHash implements Ordered {
  constructor(public value: Fr, public counter: number, public length: number) {}

  toFields(): Fr[] {
    return [this.value, new Fr(this.counter), new Fr(this.length)];
  }

  static fromFields(fields: Fr[] | FieldReader) {
    const reader = FieldReader.asReader(fields);
    return new LogHash(reader.readField(), reader.readU32(), reader.readU32());
  }

  isEmpty() {
    return this.value.isZero() && !this.length && !this.counter;
  }

  static empty() {
    return new LogHash(Fr.zero(), 0, 0);
  }

  toBuffer(): Buffer {
    return serializeToBuffer(this.value, this.counter, this.length);
  }

  static fromBuffer(buffer: Buffer | BufferReader) {
    const reader = BufferReader.asReader(buffer);
    return new LogHash(Fr.fromBuffer(reader), reader.readNumber(), reader.readNumber());
  }

  toString(): string {
    return `value=${this.value} counter=${this.counter} length=${this.length}`;
  }

  scope(contractAddress: AztecAddress) {
    return new ScopedLogHash(this, contractAddress);
  }

  [inspect.custom](): string {
    return `LogHash { ${this.toString()} }`;
  }
}

export class ScopedLogHash implements Ordered {
  constructor(public logHash: LogHash, public contractAddress: AztecAddress) {}

  get counter() {
    return this.logHash.counter;
  }

  get value() {
    return this.logHash.value;
  }

  toFields(): Fr[] {
    return [...this.logHash.toFields(), this.contractAddress.toField()];
  }

  static fromFields(fields: Fr[] | FieldReader) {
    const reader = FieldReader.asReader(fields);
    return new ScopedLogHash(reader.readObject(LogHash), AztecAddress.fromField(reader.readField()));
  }

  isEmpty() {
    return this.logHash.isEmpty() && this.contractAddress.isZero();
  }

  static empty() {
    return new ScopedLogHash(LogHash.empty(), AztecAddress.ZERO);
  }

  toBuffer(): Buffer {
    return serializeToBuffer(this.logHash, this.contractAddress);
  }

  static fromBuffer(buffer: Buffer | BufferReader) {
    const reader = BufferReader.asReader(buffer);
    return new ScopedLogHash(LogHash.fromBuffer(reader), AztecAddress.fromBuffer(reader));
  }

  toString(): string {
    return `logHash=${this.logHash} contractAddress=${this.contractAddress}`;
  }
}
