// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract Groth16Verifier {
    // Scalar field size
    uint256 constant r =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax =
        15983927181659643788332309670580814298237638105195789234761907526687404461070;
    uint256 constant alphay =
        7980307493221757684951546827076116493047326164591700931055234724166410844768;
    uint256 constant betax1 =
        11213950079434659922235410703486197714051913638278501694052014993713956433188;
    uint256 constant betax2 =
        12654051339853072045578137474592812709036417861712492903752979492999202185956;
    uint256 constant betay1 =
        15901623162914264565042318475457369455275111670141524395000104755564027556661;
    uint256 constant betay2 =
        8822369395320652046043149782107273002236456245950268216619747569972301056672;
    uint256 constant gammax1 =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 =
        4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 =
        8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 =
        16619810242802954794297916914906534851937972935999071759270901181197585220081;
    uint256 constant deltax2 =
        12372422131365727275447533845007142130917114718803836966351200803240955366681;
    uint256 constant deltay1 =
        4937814021015335684505258699541860753061540681117133314495505146164357222953;
    uint256 constant deltay2 =
        272394747958892973682802855146122924856097132553365887312529529061556231100;

    uint256 constant IC0x =
        11025339344863037094339526741410774083593576539674128928649182810315840464090;
    uint256 constant IC0y =
        18144560603667294263891616819536729633461541605521877371049141530459440837889;

    uint256 constant IC1x =
        8766701715357705859245813500106548645271546831830667673764804741647367040023;
    uint256 constant IC1y =
        10805302807118138543025309745167296218712630195145991348620320971521708630504;

    uint256 constant IC2x =
        17720134018214518300388113230419491119549378695630321248967016278695968585115;
    uint256 constant IC2y =
        56693381204423552412033167892280828121834291980409562892403966214472585391;

    uint256 constant IC3x =
        15768500693305815496704690414486489441144759282624267573959738146284970825104;
    uint256 constant IC3y =
        21094068596090794261514249442362506909998119185623806749708197997914497555166;

    uint256 constant IC4x =
        13327436818443007698360876797772025649272291424098214261941073846500056986988;
    uint256 constant IC4y =
        17626534533382769207554362281913169281933451283046534541412918876501324044217;

    uint256 constant IC5x =
        6773907700530040359231784084108035793671458078151116045500574053471434302723;
    uint256 constant IC5y =
        18649502463947162286320810564927696046757415896011816595695856525961442428176;

    uint256 constant IC6x =
        14966087824397889599485413144395639234631740556221310069427220877940344121323;
    uint256 constant IC6y =
        13006425287870254201548088523351380301607971648206167584661818297268161147450;

    uint256 constant IC7x =
        15636651652272801013344553895077550771415782104540995851126199446729706392402;
    uint256 constant IC7y =
        19803624127050247244594269686056472917936936401522444853029575830002851958479;

    uint256 constant IC8x =
        9307000074980858660739727437195873796996098982211576613624282759780480098113;
    uint256 constant IC8y =
        19813024207295818219524266357058432426945565499065942227459012836594470954284;

    uint256 constant IC9x =
        20233649265417403498011096424398176811238351294554849047422131957287869982346;
    uint256 constant IC9y =
        16868139872916883628563255324676130765147639254469842528070084755803898506358;

    uint256 constant IC10x =
        6770371806301773683971827187524575880432714826034716262308269425509041486238;
    uint256 constant IC10y =
        1982941886863422371659196824351577850828393708981138616565272184480495707144;

    uint256 constant IC11x =
        10822485864172649573427534565094835056366254034119022715155450752582819881318;
    uint256 constant IC11y =
        17794623155364439038222901266598122517556767842865169981028392407370935840892;

    uint256 constant IC12x =
        19796854890642527189874247982915173460435615403961109379341717842392475099509;
    uint256 constant IC12y =
        4041793850478066422585896030956780883475309988033644043439139302503663213591;

    uint256 constant IC13x =
        15181977204793086236524595756016858470659459786267029781159095731693338353818;
    uint256 constant IC13y =
        18802984637507763744417167928481543924286754216314393473111722293459912517870;

    uint256 constant IC14x =
        2517353490343399017516451541783370062900123018654950043997093144661825315498;
    uint256 constant IC14y =
        20216961658478557179982238985983092217923340935133452081864470672793917076460;

    uint256 constant IC15x =
        3661614826613789635491549078473268594498746587635009319171416932325940482245;
    uint256 constant IC15y =
        16516675568351112747957410959826090972566336725631310414031646284669925756174;

    uint256 constant IC16x =
        6267988241735911046143377602402400576682701646674008773424104954119211890731;
    uint256 constant IC16y =
        6007302210103457645605381441220721742649118533795501100683404746425272397906;

    uint256 constant IC17x =
        16484303416173202712822325393648823642921184523459822563684279570653698972800;
    uint256 constant IC17y =
        18112305252757372742635766734527436563836178751292336379276683320658449747639;

    uint256 constant IC18x =
        1137481060400200273278686117990444228672528317446822083356684980834841391435;
    uint256 constant IC18y =
        2533150442206681347530569188535158466791130262844960160645178652811732325049;

    uint256 constant IC19x =
        19944731310998308199977336973073897738077867176514317137189250002687202583340;
    uint256 constant IC19y =
        3013332044828512616434689937797530290090843672963005058007741144314122660179;

    uint256 constant IC20x =
        2954760093244029053366565473752506232882223390105741258231115990961194978463;
    uint256 constant IC20y =
        10943212730152104575587334589215268468186753250184691195771461731715579975330;

    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[20] calldata _pubSignals
    ) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x

                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))

                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))

                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))

                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))

                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))

                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))

                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))

                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))

                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))

                g1_mulAccC(
                    _pVk,
                    IC10x,
                    IC10y,
                    calldataload(add(pubSignals, 288))
                )

                g1_mulAccC(
                    _pVk,
                    IC11x,
                    IC11y,
                    calldataload(add(pubSignals, 320))
                )

                g1_mulAccC(
                    _pVk,
                    IC12x,
                    IC12y,
                    calldataload(add(pubSignals, 352))
                )

                g1_mulAccC(
                    _pVk,
                    IC13x,
                    IC13y,
                    calldataload(add(pubSignals, 384))
                )

                g1_mulAccC(
                    _pVk,
                    IC14x,
                    IC14y,
                    calldataload(add(pubSignals, 416))
                )

                g1_mulAccC(
                    _pVk,
                    IC15x,
                    IC15y,
                    calldataload(add(pubSignals, 448))
                )

                g1_mulAccC(
                    _pVk,
                    IC16x,
                    IC16y,
                    calldataload(add(pubSignals, 480))
                )

                g1_mulAccC(
                    _pVk,
                    IC17x,
                    IC17y,
                    calldataload(add(pubSignals, 512))
                )

                g1_mulAccC(
                    _pVk,
                    IC18x,
                    IC18y,
                    calldataload(add(pubSignals, 544))
                )

                g1_mulAccC(
                    _pVk,
                    IC19x,
                    IC19y,
                    calldataload(add(pubSignals, 576))
                )

                g1_mulAccC(
                    _pVk,
                    IC20x,
                    IC20y,
                    calldataload(add(pubSignals, 608))
                )

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(
                    add(_pPairing, 32),
                    mod(sub(q, calldataload(add(pA, 32))), q)
                )

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))

                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)

                let success := staticcall(
                    sub(gas(), 2000),
                    8,
                    _pPairing,
                    768,
                    _pPairing,
                    0x20
                )

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F

            checkField(calldataload(add(_pubSignals, 0)))

            checkField(calldataload(add(_pubSignals, 32)))

            checkField(calldataload(add(_pubSignals, 64)))

            checkField(calldataload(add(_pubSignals, 96)))

            checkField(calldataload(add(_pubSignals, 128)))

            checkField(calldataload(add(_pubSignals, 160)))

            checkField(calldataload(add(_pubSignals, 192)))

            checkField(calldataload(add(_pubSignals, 224)))

            checkField(calldataload(add(_pubSignals, 256)))

            checkField(calldataload(add(_pubSignals, 288)))

            checkField(calldataload(add(_pubSignals, 320)))

            checkField(calldataload(add(_pubSignals, 352)))

            checkField(calldataload(add(_pubSignals, 384)))

            checkField(calldataload(add(_pubSignals, 416)))

            checkField(calldataload(add(_pubSignals, 448)))

            checkField(calldataload(add(_pubSignals, 480)))

            checkField(calldataload(add(_pubSignals, 512)))

            checkField(calldataload(add(_pubSignals, 544)))

            checkField(calldataload(add(_pubSignals, 576)))

            checkField(calldataload(add(_pubSignals, 608)))

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }
}
