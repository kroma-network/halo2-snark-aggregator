use std::marker::PhantomData;

use super::ecc_chip::SolidityEccChip;
<<<<<<< HEAD
use halo2_ecc::utils::{biguint_to_fe as bn_to_field, fe_to_biguint as field_to_bn};
use halo2_proofs::arithmetic::{BaseExt, CurveAffine, Field, FieldExt};
=======
use halo2_ecc_circuit_lib::utils::{bn_to_field, field_to_bn};
use halo2_proofs::arithmetic::{CurveAffine, Field, FieldExt};
>>>>>>> scroll/scroll-dev-0920
use halo2_snark_aggregator_api::{
    arith::{common::ArithCommonChip, ecc::ArithEccChip},
    transcript::encode::Encode,
};
use pairing_bn256::group::ff::PrimeField;

pub struct PoseidonEncode<A: ArithEccChip> {
    _phantom: PhantomData<A>,
}

<<<<<<< HEAD
fn base_to_scalar<B: BaseExt + PrimeField, S: FieldExt>(base: &B) -> S {
=======
fn base_to_scalar<B: FieldExt, S: FieldExt>(base: &B) -> S {
>>>>>>> scroll/scroll-dev-0920
    let bn = field_to_bn(base);
    let modulus = field_to_bn(&-B::one()) + 1u64;
    let bn = bn % modulus;
    bn_to_field(&bn)
}

impl<C: CurveAffine, E> Encode<SolidityEccChip<C, E>> for PoseidonEncode<SolidityEccChip<C, E>>
where
    C::Base: PrimeField,
{
    fn encode_point(
        ctx: &mut <SolidityEccChip<C, E> as ArithCommonChip>::Context,
        nchip: &<SolidityEccChip<C, E> as ArithEccChip>::NativeChip,
        _: &<SolidityEccChip<C, E> as ArithEccChip>::ScalarChip,
        pchip: &SolidityEccChip<C, E>,
        v: &<SolidityEccChip<C, E> as ArithEccChip>::AssignedPoint,
    ) -> Result<Vec<<SolidityEccChip<C, E> as ArithEccChip>::AssignedNative>, E> {
        let p = pchip.to_value(v)?;
        let c = p.coordinates();
        let x = c.map(|v| *v.x()).unwrap_or(
            <<SolidityEccChip<C, E> as ArithEccChip>::Point as CurveAffine>::Base::zero(),
        );
        let y = c.map(|v| *v.y()).unwrap_or(
            <<SolidityEccChip<C, E> as ArithEccChip>::Point as CurveAffine>::Base::zero(),
        );

        let px = nchip.assign_var(ctx, base_to_scalar(&x))?;
        let py = nchip.assign_var(ctx, base_to_scalar(&y))?;

        Ok(vec![px, py])
    }

    fn encode_scalar(
        _: &mut <SolidityEccChip<C, E> as ArithCommonChip>::Context,
        _: &<SolidityEccChip<C, E> as ArithEccChip>::NativeChip,
        _: &<SolidityEccChip<C, E> as ArithEccChip>::ScalarChip,
        v: &<SolidityEccChip<C, E> as ArithEccChip>::AssignedScalar,
    ) -> Result<Vec<<SolidityEccChip<C, E> as ArithEccChip>::AssignedNative>, E> {
        Ok(vec![v.clone()])
    }

    fn decode_scalar(
        _: &mut <SolidityEccChip<C, E> as ArithCommonChip>::Context,
        _: &<SolidityEccChip<C, E> as ArithEccChip>::NativeChip,
        _: &<SolidityEccChip<C, E> as ArithEccChip>::ScalarChip,
        v: &[<SolidityEccChip<C, E> as ArithEccChip>::AssignedNative],
    ) -> Result<<SolidityEccChip<C, E> as ArithEccChip>::AssignedScalar, E> {
        Ok(v[0].clone())
    }
}
