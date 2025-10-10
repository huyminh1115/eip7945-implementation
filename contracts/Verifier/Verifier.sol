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

/**
 * @title Verifier
 * @dev A unified verifier contract that combines BurnVerifier and TransferVerifier
 * @notice This contract eliminates duplicate code by sharing common verification logic
 * and field constants between burn and transfer operations
 */
contract Verifier {
    // ============ SHARED FIELD CONSTANTS ============
    // Scalar field size - shared between both verifiers
    uint256 constant r =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size - shared between both verifiers
    uint256 constant q =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // ============ BURN VERIFICATION KEY ============
    uint256 constant BURN_ALPHAX =
        5456630902874979022504266397897370308256290626790263568897956086077045040724;
    uint256 constant BURN_ALPHAY =
        15543940088683949978350745201728249206379253754991071132711273887087817374812;
    uint256 constant BURN_BETAX1 =
        5059314700273593518342641348723800845264908827928731987049024572244517350908;
    uint256 constant BURN_BETAX2 =
        15580937769119694551456709466503667321010654883512161122525977338165764464253;
    uint256 constant BURN_BETAY1 =
        5369078478661891558161947501687453447113178970454823471564133902571677348658;
    uint256 constant BURN_BETAY2 =
        3224067520328624397506583489618822426879731855692967204528908062560642792866;
    uint256 constant BURN_GAMMAX1 =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant BURN_GAMMAX2 =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant BURN_GAMMAY1 =
        4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant BURN_GAMMAY2 =
        8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant BURN_DELTAX1 =
        10144852886712702608993185368976623013936777335465664544929464247398540624454;
    uint256 constant BURN_DELTAX2 =
        6092748586599209115356771633640253884598487671300917127199008938221994489485;
    uint256 constant BURN_DELTAY1 =
        12467538174446145885422813868310610165477681583938342014989275666072582156216;
    uint256 constant BURN_DELTAY2 =
        3884700825259982325230850681218754404770512336759106495616400449813014451791;

    // Burn IC constants (IC0-IC8)
    uint256 constant BURN_IC0X =
        8785745844311750665067190704382911068325051145091930940032851943070063204201;
    uint256 constant BURN_IC0Y =
        16683422500081266583083100789473112813652083768382329345962894881406173099583;
    uint256 constant BURN_IC1X =
        14200306712571489991796380014880919328521825796355088340714467454750577789677;
    uint256 constant BURN_IC1Y =
        7886343278059013942194634190334160717456615881729512134743243563015135238521;
    uint256 constant BURN_IC2X =
        3891490920958355255111691073262141851337345019549142928649057032969355112211;
    uint256 constant BURN_IC2Y =
        7793296899311520987948278796054738618430114917888096014144157695994941838225;
    uint256 constant BURN_IC3X =
        4282955914321781694359011693383581109467646445761751962958964962718643937013;
    uint256 constant BURN_IC3Y =
        6379113183762494054168398737592136705003434337161502552897937922750134538181;
    uint256 constant BURN_IC4X =
        4205860463564897976254734609794722325554767696745499004440066483782590053046;
    uint256 constant BURN_IC4Y =
        14151498606028642814439524568973877071215319317665957859212789258074023921339;
    uint256 constant BURN_IC5X =
        21755751379466799758942866305528105862531951749590867285953950140211493168143;
    uint256 constant BURN_IC5Y =
        20565490516209748874056684767230141058326498184633733586843287015770732894276;
    uint256 constant BURN_IC6X =
        19543229610443580774178746479180703231904161621925762020260586508968363919653;
    uint256 constant BURN_IC6Y =
        4672413941017151421462966211245623058111672359072414091715890717211446843659;
    uint256 constant BURN_IC7X =
        1180299076010168035340021625307327574470909947180727100146666936405507076992;
    uint256 constant BURN_IC7Y =
        19317978429917568947076308131630589249860672366953523889676525524038736449344;
    uint256 constant BURN_IC8X =
        5444381024942533086344884109335534839768463842981153046141217497823017130430;
    uint256 constant BURN_IC8Y =
        20285524104142083860963196434189061217269395896729495324751120693066932641148;

    // ============ TRANSFER VERIFICATION KEY ============
    uint256 constant TRANSFER_ALPHAX =
        690365547947261052114072781428907499366672006420806726632220606597136161243;
    uint256 constant TRANSFER_ALPHAY =
        6050953851535478557839677471428357681767984213403940569012011729721607456781;
    uint256 constant TRANSFER_BETAX1 =
        10872443184221910359337949881799938437735535794467948501140130212148005083022;
    uint256 constant TRANSFER_BETAX2 =
        7861200681754382423676763476942697328397907887606844083760049799953647744867;
    uint256 constant TRANSFER_BETAY1 =
        10950630238047147917408286041518394358659670769850662586146314160743802682559;
    uint256 constant TRANSFER_BETAY2 =
        2237495802999866506167374844987679605957600361282367001260732295479395028017;
    uint256 constant TRANSFER_GAMMAX1 =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant TRANSFER_GAMMAX2 =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant TRANSFER_GAMMAY1 =
        4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant TRANSFER_GAMMAY2 =
        8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant TRANSFER_DELTAX1 =
        5461616477949288877352339649678458238857573096149685839862753106122065485994;
    uint256 constant TRANSFER_DELTAX2 =
        13908105317254982979600532035929751290935512116047127055237023278378206496818;
    uint256 constant TRANSFER_DELTAY1 =
        6258862397544340499656734079369275493883915747634038170576080763668297267018;
    uint256 constant TRANSFER_DELTAY2 =
        19665849730126068674089997150539664502687448054955893217366785830634882295211;

    // Transfer IC constants (IC0-IC16)
    uint256 constant TRANSFER_IC0X =
        60652427697150610898657708490005073365333608343061945157808720563818679289;
    uint256 constant TRANSFER_IC0Y =
        7653061247613369615439379704366601550796900878719415157727292050750540389284;
    uint256 constant TRANSFER_IC1X =
        2276142011228441496036111944589252036915811063496247969724465610947259587019;
    uint256 constant TRANSFER_IC1Y =
        20469066670689535746029317015408962451610487548416662494041361861953697230557;
    uint256 constant TRANSFER_IC2X =
        14170881738503618929814933668711155305064124639904204585940767907502373773586;
    uint256 constant TRANSFER_IC2Y =
        20945617726284078135208484942500030904641082577299328934975298318953389378492;
    uint256 constant TRANSFER_IC3X =
        18870770008394266403613586536076577987770545437348642302966339021977806253809;
    uint256 constant TRANSFER_IC3Y =
        16263030606001031936904125259738299736138311192834023450301860217436870875177;
    uint256 constant TRANSFER_IC4X =
        4952427268695251788510971380503085770801518138237361769038251696419856986751;
    uint256 constant TRANSFER_IC4Y =
        12113577392049685987549438725152021915498526148112397375087630821763828438790;
    uint256 constant TRANSFER_IC5X =
        8870856349526660101112797270164718679145268429228784656227559922832479732734;
    uint256 constant TRANSFER_IC5Y =
        1427240541428930638810183356137868777541725684848699120950971622923856602639;
    uint256 constant TRANSFER_IC6X =
        17227899721140512611495914612306696144880912064497840106325072383344370099699;
    uint256 constant TRANSFER_IC6Y =
        1522891353952477830519770659489034977222578445185475975823669893403455024735;
    uint256 constant TRANSFER_IC7X =
        18975483516256982821027665795179628808258788445468297294179901903668122790955;
    uint256 constant TRANSFER_IC7Y =
        20687268470954935333175200356974427037019760771025227542022129038127084159246;
    uint256 constant TRANSFER_IC8X =
        21032633153224167431666429808137469436334505202306228155401938093897616840545;
    uint256 constant TRANSFER_IC8Y =
        16006739431086399602188502634423598771071563229484496067830612820954965822873;
    uint256 constant TRANSFER_IC9X =
        8402665306187194234255558142971534172592582224949478788892441400540313019310;
    uint256 constant TRANSFER_IC9Y =
        10524638861508412805653157577299477158862545079159460034596545779912160062191;
    uint256 constant TRANSFER_IC10X =
        15374296701180543944585066990582002113086786488386087153548493481988331934993;
    uint256 constant TRANSFER_IC10Y =
        14443007494411329759353694029533341956978871973524076111737665593552070092603;
    uint256 constant TRANSFER_IC11X =
        18032756137224250422400779737480432718350424596620240987426158922862909977233;
    uint256 constant TRANSFER_IC11Y =
        15449379463006742660325137203737892799988873764606256086770279832842454179381;
    uint256 constant TRANSFER_IC12X =
        1681186384756245033064687708450104297231938227145129699543208617151057770470;
    uint256 constant TRANSFER_IC12Y =
        15678314456428560025411475848396887057347434800310400785080018598950939496467;
    uint256 constant TRANSFER_IC13X =
        7228437966127624470560165337953120551702863540113923072525294093205168330457;
    uint256 constant TRANSFER_IC13Y =
        16468247452436642748669990930235652970338303905868575826768611936032776727868;
    uint256 constant TRANSFER_IC14X =
        6571527173763765900550860492899198853768521595207984253780523832174977017874;
    uint256 constant TRANSFER_IC14Y =
        8552946674671723180783984127502025782742333523027257497870612626747664141779;
    uint256 constant TRANSFER_IC15X =
        17640776185899470764423806062101306192155166893071373478296603412470810841393;
    uint256 constant TRANSFER_IC15Y =
        18679620020989473901328077874095687147979282045674963875196811226011923246233;
    uint256 constant TRANSFER_IC16X =
        21532750327035562120740047166632583565420253988805417202214394261128550498351;
    uint256 constant TRANSFER_IC16Y =
        14362986522552219744928470583585506612098621782918123206148180451615526001576;

    // ============ TRANSFER FROM VERIFICATION KEY ============
    // These constants are imported from TransferFromVerifier and prefixed to avoid collisions
    uint256 constant TRANSFER_FROM_ALPHAX =
        15983927181659643788332309670580814298237638105195789234761907526687404461070;
    uint256 constant TRANSFER_FROM_ALPHAY =
        7980307493221757684951546827076116493047326164591700931055234724166410844768;
    uint256 constant TRANSFER_FROM_BETAX1 =
        11213950079434659922235410703486197714051913638278501694052014993713956433188;
    uint256 constant TRANSFER_FROM_BETAX2 =
        12654051339853072045578137474592812709036417861712492903752979492999202185956;
    uint256 constant TRANSFER_FROM_BETAY1 =
        15901623162914264565042318475457369455275111670141524395000104755564027556661;
    uint256 constant TRANSFER_FROM_BETAY2 =
        8822369395320652046043149782107273002236456245950268216619747569972301056672;
    uint256 constant TRANSFER_FROM_GAMMAX1 =
        11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant TRANSFER_FROM_GAMMAX2 =
        10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant TRANSFER_FROM_GAMMAY1 =
        4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant TRANSFER_FROM_GAMMAY2 =
        8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant TRANSFER_FROM_DELTAX1 =
        16619810242802954794297916914906534851937972935999071759270901181197585220081;
    uint256 constant TRANSFER_FROM_DELTAX2 =
        12372422131365727275447533845007142130917114718803836966351200803240955366681;
    uint256 constant TRANSFER_FROM_DELTAY1 =
        4937814021015335684505258699541860753061540681117133314495505146164357222953;
    uint256 constant TRANSFER_FROM_DELTAY2 =
        272394747958892973682802855146122924856097132553365887312529529061556231100;

    // TransferFrom IC constants (IC0-IC20)
    uint256 constant TRANSFER_FROM_IC0X =
        11025339344863037094339526741410774083593576539674128928649182810315840464090;
    uint256 constant TRANSFER_FROM_IC0Y =
        18144560603667294263891616819536729633461541605521877371049141530459440837889;
    uint256 constant TRANSFER_FROM_IC1X =
        8766701715357705859245813500106548645271546831830667673764804741647367040023;
    uint256 constant TRANSFER_FROM_IC1Y =
        10805302807118138543025309745167296218712630195145991348620320971521708630504;
    uint256 constant TRANSFER_FROM_IC2X =
        17720134018214518300388113230419491119549378695630321248967016278695968585115;
    uint256 constant TRANSFER_FROM_IC2Y =
        56693381204423552412033167892280828121834291980409562892403966214472585391;
    uint256 constant TRANSFER_FROM_IC3X =
        15768500693305815496704690414486489441144759282624267573959738146284970825104;
    uint256 constant TRANSFER_FROM_IC3Y =
        21094068596090794261514249442362506909998119185623806749708197997914497555166;
    uint256 constant TRANSFER_FROM_IC4X =
        13327436818443007698360876797772025649272291424098214261941073846500056986988;
    uint256 constant TRANSFER_FROM_IC4Y =
        17626534533382769207554362281913169281933451283046534541412918876501324044217;
    uint256 constant TRANSFER_FROM_IC5X =
        6773907700530040359231784084108035793671458078151116045500574053471434302723;
    uint256 constant TRANSFER_FROM_IC5Y =
        18649502463947162286320810564927696046757415896011816595695856525961442428176;
    uint256 constant TRANSFER_FROM_IC6X =
        14966087824397889599485413144395639234631740556221310069427220877940344121323;
    uint256 constant TRANSFER_FROM_IC6Y =
        13006425287870254201548088523351380301607971648206167584661818297268161147450;
    uint256 constant TRANSFER_FROM_IC7X =
        15636651652272801013344553895077550771415782104540995851126199446729706392402;
    uint256 constant TRANSFER_FROM_IC7Y =
        19803624127050247244594269686056472917936936401522444853029575830002851958479;
    uint256 constant TRANSFER_FROM_IC8X =
        9307000074980858660739727437195873796996098982211576613624282759780480098113;
    uint256 constant TRANSFER_FROM_IC8Y =
        19813024207295818219524266357058432426945565499065942227459012836594470954284;
    uint256 constant TRANSFER_FROM_IC9X =
        20233649265417403498011096424398176811238351294554849047422131957287869982346;
    uint256 constant TRANSFER_FROM_IC9Y =
        16868139872916883628563255324676130765147639254469842528070084755803898506358;
    uint256 constant TRANSFER_FROM_IC10X =
        6770371806301773683971827187524575880432714826034716262308269425509041486238;
    uint256 constant TRANSFER_FROM_IC10Y =
        1982941886863422371659196824351577850828393708981138616565272184480495707144;
    uint256 constant TRANSFER_FROM_IC11X =
        10822485864172649573427534565094835056366254034119022715155450752582819881318;
    uint256 constant TRANSFER_FROM_IC11Y =
        17794623155364439038222901266598122517556767842865169981028392407370935840892;
    uint256 constant TRANSFER_FROM_IC12X =
        19796854890642527189874247982915173460435615403961109379341717842392475099509;
    uint256 constant TRANSFER_FROM_IC12Y =
        4041793850478066422585896030956780883475309988033644043439139302503663213591;
    uint256 constant TRANSFER_FROM_IC13X =
        15181977204793086236524595756016858470659459786267029781159095731693338353818;
    uint256 constant TRANSFER_FROM_IC13Y =
        18802984637507763744417167928481543924286754216314393473111722293459912517870;
    uint256 constant TRANSFER_FROM_IC14X =
        2517353490343399017516451541783370062900123018654950043997093144661825315498;
    uint256 constant TRANSFER_FROM_IC14Y =
        20216961658478557179982238985983092217923340935133452081864470672793917076460;
    uint256 constant TRANSFER_FROM_IC15X =
        3661614826613789635491549078473268594498746587635009319171416932325940482245;
    uint256 constant TRANSFER_FROM_IC15Y =
        16516675568351112747957410959826090972566336725631310414031646284669925756174;
    uint256 constant TRANSFER_FROM_IC16X =
        6267988241735911046143377602402400576682701646674008773424104954119211890731;
    uint256 constant TRANSFER_FROM_IC16Y =
        6007302210103457645605381441220721742649118533795501100683404746425272397906;
    uint256 constant TRANSFER_FROM_IC17X =
        16484303416173202712822325393648823642921184523459822563684279570653698972800;
    uint256 constant TRANSFER_FROM_IC17Y =
        18112305252757372742635766734527436563836178751292336379276683320658449747639;
    uint256 constant TRANSFER_FROM_IC18X =
        1137481060400200273278686117990444228672528317446822083356684980834841391435;
    uint256 constant TRANSFER_FROM_IC18Y =
        2533150442206681347530569188535158466791130262844960160645178652811732325049;
    uint256 constant TRANSFER_FROM_IC19X =
        19944731310998308199977336973073897738077867176514317137189250002687202583340;
    uint256 constant TRANSFER_FROM_IC19Y =
        3013332044828512616434689937797530290090843672963005058007741144314122660179;
    uint256 constant TRANSFER_FROM_IC20X =
        2954760093244029053366565473752506232882223390105741258231115990961194978463;
    uint256 constant TRANSFER_FROM_IC20Y =
        10943212730152104575587334589215268468186753250184691195771461731715579975330;

    // ============ SHARED MEMORY CONSTANTS ============
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;
    uint16 constant pLastMem = 896;

    // ============ BURN VERIFICATION FUNCTIONS ============

    /**
     * @dev Verifies a burn proof with 8 public signals
     * @param _pA Proof A coordinates
     * @param _pB Proof B coordinates
     * @param _pC Proof C coordinates
     * @param _pubSignals 8 public signals for burn verification
     * @return bool Whether the proof is valid
     */
    function verifyBurnProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[8] calldata _pubSignals
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

                mstore(_pVk, BURN_IC0X)
                mstore(add(_pVk, 32), BURN_IC0Y)

                // Compute the linear combination vk_x for burn
                g1_mulAccC(
                    _pVk,
                    BURN_IC1X,
                    BURN_IC1Y,
                    calldataload(add(pubSignals, 0))
                )
                g1_mulAccC(
                    _pVk,
                    BURN_IC2X,
                    BURN_IC2Y,
                    calldataload(add(pubSignals, 32))
                )
                g1_mulAccC(
                    _pVk,
                    BURN_IC3X,
                    BURN_IC3Y,
                    calldataload(add(pubSignals, 64))
                )
                g1_mulAccC(
                    _pVk,
                    BURN_IC4X,
                    BURN_IC4Y,
                    calldataload(add(pubSignals, 96))
                )
                g1_mulAccC(
                    _pVk,
                    BURN_IC5X,
                    BURN_IC5Y,
                    calldataload(add(pubSignals, 128))
                )
                g1_mulAccC(
                    _pVk,
                    BURN_IC6X,
                    BURN_IC6Y,
                    calldataload(add(pubSignals, 160))
                )
                g1_mulAccC(
                    _pVk,
                    BURN_IC7X,
                    BURN_IC7Y,
                    calldataload(add(pubSignals, 192))
                )
                g1_mulAccC(
                    _pVk,
                    BURN_IC8X,
                    BURN_IC8Y,
                    calldataload(add(pubSignals, 224))
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
                mstore(add(_pPairing, 192), BURN_ALPHAX)
                mstore(add(_pPairing, 224), BURN_ALPHAY)

                // beta2
                mstore(add(_pPairing, 256), BURN_BETAX1)
                mstore(add(_pPairing, 288), BURN_BETAX2)
                mstore(add(_pPairing, 320), BURN_BETAY1)
                mstore(add(_pPairing, 352), BURN_BETAY2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))

                // gamma2
                mstore(add(_pPairing, 448), BURN_GAMMAX1)
                mstore(add(_pPairing, 480), BURN_GAMMAX2)
                mstore(add(_pPairing, 512), BURN_GAMMAY1)
                mstore(add(_pPairing, 544), BURN_GAMMAY2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), BURN_DELTAX1)
                mstore(add(_pPairing, 672), BURN_DELTAX2)
                mstore(add(_pPairing, 704), BURN_DELTAY1)
                mstore(add(_pPairing, 736), BURN_DELTAY2)

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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }

    /**
     * @dev Convenience function for burn proof verification with flat array
     * @param _proof Flat proof array [A0, A1, B00, B01, B10, B11, C0, C1]
     * @param _pubSignals 8 public signals for burn verification
     * @return bool Whether the proof is valid
     */
    function verifyBurnProof(
        uint256[8] memory _proof,
        uint[8] calldata _pubSignals
    ) public view returns (bool) {
        uint[2] memory _pA;
        uint[2][2] memory _pB;
        uint[2] memory _pC;

        _pA[0] = _proof[0];
        _pA[1] = _proof[1];

        _pB[0][0] = _proof[2];
        _pB[0][1] = _proof[3];
        _pB[1][0] = _proof[4];
        _pB[1][1] = _proof[5];

        _pC[0] = _proof[6];
        _pC[1] = _proof[7];

        return this.verifyBurnProof(_pA, _pB, _pC, _pubSignals);
    }

    // ============ TRANSFER VERIFICATION FUNCTIONS ============

    /**
     * @dev Verifies a transfer proof with 16 public signals
     * @param _pA Proof A coordinates
     * @param _pB Proof B coordinates
     * @param _pC Proof C coordinates
     * @param _pubSignals 16 public signals for transfer verification
     * @return bool Whether the proof is valid
     */
    function verifyTransferProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[16] calldata _pubSignals
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

                mstore(_pVk, TRANSFER_IC0X)
                mstore(add(_pVk, 32), TRANSFER_IC0Y)

                // Compute the linear combination vk_x for transfer
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC1X,
                    TRANSFER_IC1Y,
                    calldataload(add(pubSignals, 0))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC2X,
                    TRANSFER_IC2Y,
                    calldataload(add(pubSignals, 32))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC3X,
                    TRANSFER_IC3Y,
                    calldataload(add(pubSignals, 64))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC4X,
                    TRANSFER_IC4Y,
                    calldataload(add(pubSignals, 96))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC5X,
                    TRANSFER_IC5Y,
                    calldataload(add(pubSignals, 128))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC6X,
                    TRANSFER_IC6Y,
                    calldataload(add(pubSignals, 160))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC7X,
                    TRANSFER_IC7Y,
                    calldataload(add(pubSignals, 192))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC8X,
                    TRANSFER_IC8Y,
                    calldataload(add(pubSignals, 224))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC9X,
                    TRANSFER_IC9Y,
                    calldataload(add(pubSignals, 256))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC10X,
                    TRANSFER_IC10Y,
                    calldataload(add(pubSignals, 288))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC11X,
                    TRANSFER_IC11Y,
                    calldataload(add(pubSignals, 320))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC12X,
                    TRANSFER_IC12Y,
                    calldataload(add(pubSignals, 352))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC13X,
                    TRANSFER_IC13Y,
                    calldataload(add(pubSignals, 384))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC14X,
                    TRANSFER_IC14Y,
                    calldataload(add(pubSignals, 416))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC15X,
                    TRANSFER_IC15Y,
                    calldataload(add(pubSignals, 448))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_IC16X,
                    TRANSFER_IC16Y,
                    calldataload(add(pubSignals, 480))
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
                mstore(add(_pPairing, 192), TRANSFER_ALPHAX)
                mstore(add(_pPairing, 224), TRANSFER_ALPHAY)

                // beta2
                mstore(add(_pPairing, 256), TRANSFER_BETAX1)
                mstore(add(_pPairing, 288), TRANSFER_BETAX2)
                mstore(add(_pPairing, 320), TRANSFER_BETAY1)
                mstore(add(_pPairing, 352), TRANSFER_BETAY2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))

                // gamma2
                mstore(add(_pPairing, 448), TRANSFER_GAMMAX1)
                mstore(add(_pPairing, 480), TRANSFER_GAMMAX2)
                mstore(add(_pPairing, 512), TRANSFER_GAMMAY1)
                mstore(add(_pPairing, 544), TRANSFER_GAMMAY2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), TRANSFER_DELTAX1)
                mstore(add(_pPairing, 672), TRANSFER_DELTAX2)
                mstore(add(_pPairing, 704), TRANSFER_DELTAY1)
                mstore(add(_pPairing, 736), TRANSFER_DELTAY2)

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

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
            return(0, 0x20)
        }
    }

    /**
     * @dev Convenience function for transfer proof verification with flat array
     * @param _proof Flat proof array [A0, A1, B00, B01, B10, B11, C0, C1]
     * @param _pubSignals 16 public signals for transfer verification
     * @return bool Whether the proof is valid
     */
    function verifyTransferProof(
        uint256[8] memory _proof,
        uint[16] calldata _pubSignals
    ) public view returns (bool) {
        uint[2] memory _pA;
        uint[2][2] memory _pB;
        uint[2] memory _pC;

        _pA[0] = _proof[0];
        _pA[1] = _proof[1];

        _pB[0][0] = _proof[2];
        _pB[0][1] = _proof[3];
        _pB[1][0] = _proof[4];
        _pB[1][1] = _proof[5];

        _pC[0] = _proof[6];
        _pC[1] = _proof[7];

        return this.verifyTransferProof(_pA, _pB, _pC, _pubSignals);
    }

    // ============ TRANSFER FROM VERIFICATION FUNCTIONS ============

    /**
     * @dev Verifies a transferFrom proof with 20 public signals
     * @param _pA Proof A coordinates
     * @param _pB Proof B coordinates
     * @param _pC Proof C coordinates
     * @param _pubSignals 20 public signals for transferFrom verification
     * @return bool Whether the proof is valid
     */
    function verifyTransferFromProof(
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

                mstore(_pVk, TRANSFER_FROM_IC0X)
                mstore(add(_pVk, 32), TRANSFER_FROM_IC0Y)

                // Compute the linear combination vk_x for transferFrom
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC1X,
                    TRANSFER_FROM_IC1Y,
                    calldataload(add(pubSignals, 0))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC2X,
                    TRANSFER_FROM_IC2Y,
                    calldataload(add(pubSignals, 32))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC3X,
                    TRANSFER_FROM_IC3Y,
                    calldataload(add(pubSignals, 64))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC4X,
                    TRANSFER_FROM_IC4Y,
                    calldataload(add(pubSignals, 96))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC5X,
                    TRANSFER_FROM_IC5Y,
                    calldataload(add(pubSignals, 128))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC6X,
                    TRANSFER_FROM_IC6Y,
                    calldataload(add(pubSignals, 160))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC7X,
                    TRANSFER_FROM_IC7Y,
                    calldataload(add(pubSignals, 192))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC8X,
                    TRANSFER_FROM_IC8Y,
                    calldataload(add(pubSignals, 224))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC9X,
                    TRANSFER_FROM_IC9Y,
                    calldataload(add(pubSignals, 256))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC10X,
                    TRANSFER_FROM_IC10Y,
                    calldataload(add(pubSignals, 288))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC11X,
                    TRANSFER_FROM_IC11Y,
                    calldataload(add(pubSignals, 320))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC12X,
                    TRANSFER_FROM_IC12Y,
                    calldataload(add(pubSignals, 352))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC13X,
                    TRANSFER_FROM_IC13Y,
                    calldataload(add(pubSignals, 384))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC14X,
                    TRANSFER_FROM_IC14Y,
                    calldataload(add(pubSignals, 416))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC15X,
                    TRANSFER_FROM_IC15Y,
                    calldataload(add(pubSignals, 448))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC16X,
                    TRANSFER_FROM_IC16Y,
                    calldataload(add(pubSignals, 480))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC17X,
                    TRANSFER_FROM_IC17Y,
                    calldataload(add(pubSignals, 512))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC18X,
                    TRANSFER_FROM_IC18Y,
                    calldataload(add(pubSignals, 544))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC19X,
                    TRANSFER_FROM_IC19Y,
                    calldataload(add(pubSignals, 576))
                )
                g1_mulAccC(
                    _pVk,
                    TRANSFER_FROM_IC20X,
                    TRANSFER_FROM_IC20Y,
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
                mstore(add(_pPairing, 192), TRANSFER_FROM_ALPHAX)
                mstore(add(_pPairing, 224), TRANSFER_FROM_ALPHAY)

                // beta2
                mstore(add(_pPairing, 256), TRANSFER_FROM_BETAX1)
                mstore(add(_pPairing, 288), TRANSFER_FROM_BETAX2)
                mstore(add(_pPairing, 320), TRANSFER_FROM_BETAY1)
                mstore(add(_pPairing, 352), TRANSFER_FROM_BETAY2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))

                // gamma2
                mstore(add(_pPairing, 448), TRANSFER_FROM_GAMMAX1)
                mstore(add(_pPairing, 480), TRANSFER_FROM_GAMMAX2)
                mstore(add(_pPairing, 512), TRANSFER_FROM_GAMMAY1)
                mstore(add(_pPairing, 544), TRANSFER_FROM_GAMMAY2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), TRANSFER_FROM_DELTAX1)
                mstore(add(_pPairing, 672), TRANSFER_FROM_DELTAX2)
                mstore(add(_pPairing, 704), TRANSFER_FROM_DELTAY1)
                mstore(add(_pPairing, 736), TRANSFER_FROM_DELTAY2)

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

    /**
     * @dev Convenience function for transferFrom proof verification with flat array
     * @param _proof Flat proof array [A0, A1, B00, B01, B10, B11, C0, C1]
     * @param _pubSignals 20 public signals for transferFrom verification
     * @return bool Whether the proof is valid
     */
    function verifyTransferFromProof(
        uint256[8] memory _proof,
        uint[20] calldata _pubSignals
    ) public view returns (bool) {
        uint[2] memory _pA;
        uint[2][2] memory _pB;
        uint[2] memory _pC;

        _pA[0] = _proof[0];
        _pA[1] = _proof[1];

        _pB[0][0] = _proof[2];
        _pB[0][1] = _proof[3];
        _pB[1][0] = _proof[4];
        _pB[1][1] = _proof[5];

        _pC[0] = _proof[6];
        _pC[1] = _proof[7];

        return this.verifyTransferFromProof(_pA, _pB, _pC, _pubSignals);
    }
}
