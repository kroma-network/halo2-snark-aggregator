#!/bin/sh

mkdir -p hardhat/
mkdir -p hardhat/src
cp ../halo2-snark-aggregator-sdk/output/verifier.sol hardhat/contracts/verifier.sol
cd hardhat
yarn install
npx hardhat test
cd -
