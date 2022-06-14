use halo2_proofs::arithmetic::BaseExt;
use halo2_proofs::plonk::keygen_vk;
use halo2_proofs::plonk::VerifyingKey;
use halo2_proofs::plonk::{create_proof, keygen_pk};
use halo2_proofs::transcript::PoseidonRead;
use halo2_proofs::transcript::{Challenge255, PoseidonWrite};
use halo2_proofs::{
    arithmetic::{CurveAffine, MultiMillerLoop},
    plonk::Circuit,
    poly::commitment::Params,
};
use rand_core::OsRng;
use serde_json::json;
use std::io::Write;

pub trait TargetCircuit<C: CurveAffine, E: MultiMillerLoop<G1Affine = C>> {
    const TARGET_CIRCUIT_K: u32;
    const PUBLIC_INPUT_SIZE: usize;

    type Circuit: Circuit<C::ScalarExt> + Default;
}

pub fn sample_circuit_setup<
    C: CurveAffine,
    E: MultiMillerLoop<G1Affine = C>,
    CIRCUIT: TargetCircuit<C, E>,
>(
    mut folder: std::path::PathBuf,
) {
    // TODO: Do not use setup in production
    let params = Params::<C>::unsafe_setup::<E>(CIRCUIT::TARGET_CIRCUIT_K);

    let circuit = CIRCUIT::Circuit::default();
    let vk = keygen_vk(&params, &circuit).expect("keygen_vk should not fail");

    {
        folder.push("sample_circuit.params");
        let mut fd = std::fs::File::create(folder.as_path()).unwrap();
        folder.pop();
        params.write(&mut fd).unwrap();
    }

    {
        folder.push("sample_circuit.vkey");
        let mut fd = std::fs::File::create(folder.as_path()).unwrap();
        folder.pop();
        vk.write(&mut fd).unwrap();
    }
}

pub fn sample_circuit_random_run<
    C: CurveAffine,
    E: MultiMillerLoop<G1Affine = C, Scalar = C::ScalarExt>,
    CIRCUIT: TargetCircuit<C, E>,
>(
    mut folder: std::path::PathBuf,
    circuit: CIRCUIT::Circuit,
    instances: &[&[C::Scalar]],
    index: usize,
) {
    let params = {
        folder.push("sample_circuit.params");
        let mut fd = std::fs::File::open(folder.as_path()).unwrap();
        folder.pop();
        Params::<C>::read(&mut fd).unwrap()
    };

    let vk = {
        folder.push("sample_circuit.vkey");
        let mut fd = std::fs::File::open(folder.as_path()).unwrap();
        folder.pop();
        VerifyingKey::<C>::read::<_, CIRCUIT::Circuit>(&mut fd, &params).unwrap()
    };

    // let constant = C::Scalar::from(7);
    // let a = C::Scalar::random(OsRng);
    // let b = C::Scalar::random(OsRng);
    // let circuit = sample_circuit_builder(a, b);
    let pk = keygen_pk(&params, vk, &circuit).expect("keygen_pk should not fail");

    // let instances: &[&[&[C::Scalar]]] = &[&[&[constant * a.square() * b.square()]]];
    let instances: &[&[&[_]]] = &[instances];
    let mut transcript = PoseidonWrite::<_, _, Challenge255<_>>::init(vec![]);
    create_proof(&params, &pk, &[circuit], instances, OsRng, &mut transcript)
        .expect("proof generation should not fail");
    let proof = transcript.finalize();

    {
        folder.push(format!("sample_circuit_proof{}.data", index));
        let mut fd = std::fs::File::create(folder.as_path()).unwrap();
        folder.pop();
        fd.write_all(&proof).unwrap();
    }

    {
        folder.push(format!("sample_circuit_instance{}.data", index));
        let mut fd = std::fs::File::create(folder.as_path()).unwrap();
        folder.pop();
        let instances = json!(instances
            .iter()
            .map(|l1| l1
                .iter()
                .map(|l2| l2
                    .iter()
                    .map(|c: &C::ScalarExt| {
                        let mut buf = vec![];
                        c.write(&mut buf).unwrap();
                        buf
                    })
                    .collect())
                .collect::<Vec<Vec<Vec<u8>>>>())
            .collect::<Vec<Vec<Vec<Vec<u8>>>>>());
        write!(fd, "{}", instances.to_string()).unwrap();
    }

    let vk = {
        folder.push("sample_circuit.vkey");
        let mut fd = std::fs::File::open(folder.as_path()).unwrap();
        folder.pop();
        VerifyingKey::<C>::read::<_, CIRCUIT::Circuit>(&mut fd, &params).unwrap()
    };
    let params = params.verifier::<E>(CIRCUIT::PUBLIC_INPUT_SIZE).unwrap();
    let strategy = halo2_proofs::plonk::SingleVerifier::new(&params);
    /*
    let constant = E::Scalar::from(7);
    let a: E::Scalar = bn_to_field(&field_to_bn(&a));
    let b: E::Scalar = bn_to_field(&field_to_bn(&b));
    let instances: &[&[&[E::Scalar]]] = &[&[&[constant * a.square() * b.square()]]];
    */
    let mut transcript = PoseidonRead::<_, _, Challenge255<_>>::init(&proof[..]);
    halo2_proofs::plonk::verify_proof::<E, _, _, _>(
        &params,
        &vk,
        strategy,
        instances,
        &mut transcript,
    )
    .unwrap();
}
