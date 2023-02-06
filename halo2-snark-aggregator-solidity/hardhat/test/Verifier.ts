import fs from 'fs';

import { BigNumber } from '@ethersproject/bignumber';
import { expect } from 'chai';
import { constants } from 'ethers';
import { constants } from 'hardhat';

import { Verifier } from '../typechain-types/contracts/verifier';

function bufferToUint256BE(buffer: Buffer): BigNumber[] {
  const buffer256: BigNumber[] = [];
  for (let i = 0; i < buffer.length / 32; i++) {
    let v = constants.Zero;
    for (let j = 0; j < 32; j++) {
      v = v.shl(8);
      v = v.add(buffer[i * 32 + j]);
    }
    buffer256.push(v);
  }

  return buffer256;
}

function bufferToUint256LE(buffer: Buffer): BigNumber[] {
  const buffer256: BigNumber[] = [];
  for (let i = 0; i < buffer.length / 32; i++) {
    let v = constants.Zero;
    let shft = constants.One;
    for (let j = 0; j < 32; j++) {
      v = v.add(shft.mul(buffer[i * 32 + j]));
      shft = shft.mul(256);
    }
    buffer256.push(v);
  }

  return buffer256;
}

describe('Verifier', () => {
  let verifier: Verifier;

  let rawProof: Buffer;
  let rawFinalPair: Buffer;

  before('read proof and final pair', async () => {
    rawProof = await fs.promises.readFile(
      '../../halo2-snark-aggregator-sdk/output/verify_circuit_proof.data',
    );
    rawFinalPair = await fs.promises.readFile(
      '../../halo2-snark-aggregator-sdk/output/verify_circuit_final_pair.data',
    );
  });

  beforeEach('deploy contract', async () => {
    const cFactory = await ethers.getContractFactory('Verifier');
    verifier = (await cFactory.deploy()) as Verifier;
  });

  it('verify with valid inputs', async () => {
    const proof = bufferToUint256LE(rawProof);
    const finalPair = bufferToUint256LE(rawFinalPair);
    expect(await verifier.verify(proof, finalPair)).to.eq(true);
  });

  it('verify with invalid proof', async () => {
    const proof = bufferToUint256LE(rawProof);
    const finalPair = bufferToUint256LE(rawFinalPair);
    proof[0] = constants.Zero;
    await expect(verifier.verify(proof, finalPair)).to.be.reverted;
  });

  it('verify with invalid final pair', async () => {
    const proof = bufferToUint256LE(rawProof);
    const finalPair = bufferToUint256LE(rawFinalPair);
    finalPair[0] = constants.Zero;
    expect(await verifier.verify(proof, finalPair)).to.eq(false);
  });
});
