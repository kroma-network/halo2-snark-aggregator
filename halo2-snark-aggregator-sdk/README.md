1. generate params and vkey for sample circuit.

```shell
mkdir output
cargo run --example simple-example --release -- --command sample_setup --folder-path ./output
// Input:
// Output: sample circuit's params and vkey
```

2. run sample circuit with some random input, and create proof.

```shell
cargo run --example simple-example --release -- --command sample_run --folder-path ./output
// Input: sample circuit's params and vkey
// Output: sample circuit's instances and transcripts (with random run)
```

3. generate params and vkey for verify circuit, it takes long time to generate large params in the first run.

```shell
cargo run --example simple-example --release -- --command verify_setup --folder-path ./output
// Input: sample circuit's params and vkey, one sample circuit's instances and transcript
// Output: verify circuit's params and vkey
```

4. run verify circuit to verify the proof of sample circuits generated in step 2.

```shell
cargo run --example simple-example --release -- --command verify_run --folder-path ./output
// Input: sample circuit's params and vkey, nproofs * sample circuit's instances and transcript, verify circuit's params and vkey
// Output: verify circuit's instances and transcript
```

5.
* verify the proof of verify circuits generated in step 4.

```shell
cargo run --example simple-example --release -- --command verify_check --folder-path ./output
// Input: verify circuit's params and vkey, instances and transcript
// Output: result (console output only)
```

* generate solidity code of verify circuits generated in step 4.

```shell
cargo run --example simple-example --release -- --command verify_solidity --folder-path ./output --template-path ../halo2-snark-aggregator-solidity/templates
// Input: verify circuit's params and vkey, instances and transcript
// Output: verify circuit's solidity code
```

TODO:
1. expose the final pair as instances.
2. see if we can load vkey from file instead of generating it again due to issue see https://github.com/zcash/halo2/issues/449, then verify circuit doesn't depend on concrete circuit anymore.

Args:
args for services:
setup: 1. target_circuit params, 2. target_circuit vkey, 3. sample target_circuit instances and transcript (so user should run it once).
run: N * (intances and transcript)
