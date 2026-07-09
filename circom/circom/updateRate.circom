pragma circom 2.1.6;

include "circomlib/circuits/bitify.circom";
include "circomlib/circuits/babyjub.circom";
include "circomlib/circuits/escalarmulany.circom";
include "circomlib/circuits/comparators.circom";

template UpdateRate(NBITS) {
    // -------- Public inputs --------
    signal input y[2];
    signal input AL[2];
    signal input AR[2];
    signal input SL[2];
    signal input SR[2];
    signal input rtp;      // floor(s / a) or fixed-point ratio

    // -------- Private witnesses ----
    signal input sk;       // secret key
    signal input s;        // total shares 
    signal input a;        // total assets
    signal input r;        // remainder: 0 <= r < a

    // -------- Constants ------------
    var G[2] = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];

    // -------- On-curve checks -------
    component chkY  = BabyCheck(); chkY.x  <== y[0];  chkY.y  <== y[1];
    component chkAL = BabyCheck(); chkAL.x <== AL[0]; chkAL.y <== AL[1];
    component chkAR = BabyCheck(); chkAR.x <== AR[0]; chkAR.y <== AR[1];
    component chkSL = BabyCheck(); chkSL.x <== SL[0]; chkSL.y <== SL[1];
    component chkSR = BabyCheck(); chkSR.x <== SR[0]; chkSR.y <== SR[1];

    // -------- Bit-bounds ------------
    component skBits = Num2Bits(NBITS); skBits.in <== sk;
    component sBits  = Num2Bits(NBITS); sBits.in  <== s;
    component aBits  = Num2Bits(NBITS); aBits.in  <== a;
    component rBits  = Num2Bits(NBITS); rBits.in  <== r;

    // -------- y = [sk]G --------------
    component pk = BabyPbk();
    pk.in <== sk;
    y[0] === pk.Ax;
    y[1] === pk.Ay;

    // -------- (1) AL = [a]G + [sk]AR --
    // [a]G
    component mul_a_G = EscalarMulAny(NBITS);
    mul_a_G.p[0] <== G[0];
    mul_a_G.p[1] <== G[1];
    for (var i = 0; i < NBITS; i++) mul_a_G.e[i] <== aBits.out[i];

    // [sk]AR
    component mul_AR_sk = EscalarMulAny(NBITS);
    mul_AR_sk.p[0] <== AR[0];
    mul_AR_sk.p[1] <== AR[1];
    for (var j = 0; j < NBITS; j++) mul_AR_sk.e[j] <== skBits.out[j];

    // sum for AL
    component add_AL = BabyAdd();
    add_AL.x1 <== mul_a_G.out[0];
    add_AL.y1 <== mul_a_G.out[1];
    add_AL.x2 <== mul_AR_sk.out[0];
    add_AL.y2 <== mul_AR_sk.out[1];

    AL[0] === add_AL.xout;
    AL[1] === add_AL.yout;

    // -------- (2) SL = [s]G + [sk]SR --
    // [s]G
    component mul_s_G = EscalarMulAny(NBITS);
    mul_s_G.p[0] <== G[0];
    mul_s_G.p[1] <== G[1];
    for (var k = 0; k < NBITS; k++) mul_s_G.e[k] <== sBits.out[k];

    // [sk]SR
    component mul_SR_sk = EscalarMulAny(NBITS);
    mul_SR_sk.p[0] <== SR[0];
    mul_SR_sk.p[1] <== SR[1];
    for (var t = 0; t < NBITS; t++) mul_SR_sk.e[t] <== skBits.out[t];

    // sum for SL
    component add_SL = BabyAdd();
    add_SL.x1 <== mul_s_G.out[0];
    add_SL.y1 <== mul_s_G.out[1];
    add_SL.x2 <== mul_SR_sk.out[0];
    add_SL.y2 <== mul_SR_sk.out[1];

    SL[0] === add_SL.xout;
    SL[1] === add_SL.yout;

    // -------- (3) integer ratio with remainder ----
    // s = a * rtp + r, with 0 <= r < a
    s === rtp * a + r;

    component lt_r_a = LessThan(NBITS);
    lt_r_a.in[0] <== r;   // r >= 0 via Num2Bits
    lt_r_a.in[1] <== a;
    lt_r_a.out === 1;     // ensures a > 0 and r < a
}

component main{public [y, AL, AR, SL, SR, rtp]} = UpdateRate(252);

/* INPUT = {
    "y": [
        "21847968061825297417219090225605021230077606664375979689919232609498569628310",
        "19655704534932545550903049736104505487372785233094657404723345615117009132870"
    ],
    "AL": [
        "19913089679697415007456171286850173965941594722394544287682681932370624161554",
        "16691783016056440127596135679558445801614876225350623617988464024160202937103"
    ],
    "AR": [
        "21250303381939017779044479110401165095087251070101601897839228014167614956565",
        "8631462370285116201251094250575472240420777528927167005944178639952184516419"
    ],
    "SL": [
        "21024102262674999567442865209181863983219561274716314977301055184471906226002",
        "6280655499514562410886684255856339417484049148346211722108814120278049876970"
    ],
    "SR": [
        "14877774218458610039080554039154811625655974620646956480198563046257336714749",
        "344491186362969621141690228901407503308681391025433473292162645611300200348"
    ],
    "rtp": "33",
    "sk": "989684980841917356420192175194090137718385886803255486827734521826538409888",
    "s": "10000",
    "a": "300",
    "r": "100"
} */