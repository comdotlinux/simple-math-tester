import 'dart:math';
import 'dart:ui' show Offset;

import 'figure.dart';

/// The highest geometry level so far; raised as families are added.
const maxGeometryLevel = 5;

/// π as the questions use it, in hundredths; the prompt says "Use π = 3.14".
const piHundredths = 314;

/// A geometry question: the figure the child sees and the answer in
/// hundredths, which [GeometryFamily.build] computes from the parameters,
/// not from the figure.
typedef FigureQuestion = ({Figure figure, int answer});

/// The geometry question families. Each has a level, its whole finite
/// parameter space (tests enumerate it) and a pure `build` that rejects
/// parameters outside that space. The name is the variant saved in the
/// history, so a family is never renamed.
///
/// Labels shown: a square one side, a rectangle two adjacent sides (the
/// unseen sides equal the opposite ones), a triangle all three sides, a
/// right triangle its two legs, an L-shape two of its three horizontal and
/// two of its three vertical edges, a circle its radius or diameter. A
/// Pythagoras triangle shows two of its sides and a `?` on the third; a
/// rectangle with a diagonal two adjacent sides and a `?` on the diagonal.
/// A triangle with a side drawn on shows the two inside angles opposite
/// the outside angle and that angle, one of the three a `?`; an isosceles
/// triangle a tick on each equal side, one angle and a `?`; a
/// quadrilateral three angles and a `?`.
enum GeometryFamily {
  squarePerimeter(1, _squareSpace, _squarePerimeter),
  rectanglePerimeter(1, _rectangleSpace, _rectanglePerimeter),
  trianglePerimeter(1, _triangleSpace, _trianglePerimeter),
  rectangleArea(2, _areaSpace, _rectangleArea),
  squareSideFromPerimeter(3, _squareSpace, _squareSideFromPerimeter),
  squareSideFromArea(3, _squareSpace, _squareSideFromArea),
  rectangleSideFromPerimeter(3, _rectangleSpace, _rectangleSideFromPerimeter),
  rectangleSideFromArea(3, _rectangleSpace, _rectangleSideFromArea),
  triangleAngle(4, _triangleAngleSpace, _triangleAngle),
  straightAngle(4, _straightSpace, _straightAngle),
  rightAngle(4, _rightSpace, _rightAngle),
  rightTriangleArea(5, _legSpace, _rightTriangleArea),
  lShapePerimeter(5, _lShapeSpace, _lShapePerimeter),
  lShapeArea(5, _lShapeSpace, _lShapeArea),
  halvesRectanglePerimeter(5, _halvesSpace, _halvesRectanglePerimeter),
  halvesRectangleArea(5, _halvesSpace, _halvesRectangleArea),
  circleCircumference(5, _diameterSpace, _circleCircumference),
  circleArea(5, _radiusSpace, _circleArea),
  verticallyOppositeAngles(4, _crossingSpace, _verticallyOppositeAngles),
  anglesAroundPoint(4, _aroundSpace, _anglesAroundPoint),
  pythagorasHypotenuse(5, _tripleLegSpace, _pythagorasHypotenuse),
  pythagorasLeg(5, _tripleLegSpace, _pythagorasLeg),
  rectangleDiagonal(5, _diagonalSpace, _rectangleDiagonal),
  exteriorAngle(4, _exteriorSpace, _exteriorAngle),
  isoscelesTriangle(4, _isoscelesSpace, _isoscelesTriangle),
  quadrilateralAngles(5, _quadrilateralSpace, _quadrilateralAngles);

  const GeometryFamily(this.level, this._space, this.build);

  final int level;
  final List<List<int>> Function() _space;

  /// The question for [params]; throws an [ArgumentError] for parameters
  /// that are not in [space].
  final FigureQuestion Function(List<int> params) build;

  /// Every parameter list of this family.
  List<List<int>> get space => _space();
}

/// One geometry problem of [level], drawn uniformly by family, then by
/// parameters. The model draws again when it repeats the one before.
(GeometryFamily, List<int>) drawGeometry(Random random, int level) {
  final families = [
    for (final family in GeometryFamily.values)
      if (family.level == level) family,
  ];
  final family = families[random.nextInt(families.length)];
  final space = family.space;
  return (family, space[random.nextInt(space.length)]);
}

/// Sides at most 12; the longer side at most 4 times the shorter, so the
/// drawing stays readable.
bool _readable(int shorter, int longer) =>
    shorter >= 1 && longer <= 12 && longer <= 4 * shorter;

void _require(bool valid, List<int> params) {
  if (!valid) throw ArgumentError.value(params, 'params');
}

final _keys = Expando<Set<String>>();

/// Whether [params] is one of [space]'s parameter lists.
bool _inSpace(List<List<int>> space, List<int> params) => (_keys[space] ??= {
  for (final p in space) p.join(','),
}).contains(params.join(','));

final _squares = [
  for (var side = 1; side <= 12; side++) [side],
];
final _rectangles = [
  for (var width = 1; width <= 12; width++)
    for (var height = 1; height <= 12; height++)
      if (width != height && _readable(min(width, height), max(width, height)))
        [width, height],
];
final _triangles = [
  for (var base = 2; base <= 12; base++)
    for (var right = 2; right <= base; right++)
      for (var left = 2; left <= right; left++)
        if (_validTriangle(base, left, right)) [base, left, right],
];
final _areas = [
  for (var width = 1; width <= 10; width++)
    for (var height = 1; height <= 10; height++)
      if (_readable(min(width, height), max(width, height))) [width, height],
];

/// Two angles of a triangle, each at least 20°, and the third as well.
final _triangleAngles = [
  for (var a = 20; a <= 140; a++)
    for (var b = 20; a + b <= 160; b++) [a, b],
];
final _straight = [
  for (var a = 20; a <= 160; a++) [a],
];
final _right = [
  for (var a = 10; a <= 80; a++) [a],
];

/// Legs 1 to 12 whose smaller angle is at least 20°.
final _legs = [
  for (var a = 1; a <= 12; a++)
    for (var b = 1; b <= 12; b++)
      if (min(a, b) / max(a, b) >= tan(20 * pi / 180)) [a, b],
];

/// An L-shape: the outer width and height, and the corner cut away at the
/// top right. Outer sides 4 to 12, wider than tall (a taller one is the
/// same shape turned, and its labels would not fit a phone at large text),
/// and every edge at least a quarter of the width, the L-shape's version
/// of the 4 to 1 rule.
final _lShapes = [
  for (var width = 5; width <= 12; width++)
    for (var height = 4; height < width; height++)
      for (var cutWidth = 1; cutWidth < width; cutWidth++)
        for (var cutHeight = 1; cutHeight < height; cutHeight++)
          if ([
            width,
            height,
            cutWidth,
            cutHeight,
            width - cutWidth,
            height - cutHeight,
          ].every((edge) => 4 * edge >= max(width, height)))
            [width, height, cutWidth, cutHeight],
];

/// Rectangles with sides in halves (params in half units, 1 to 24), at
/// least one side not whole.
final _halves = [
  for (var width = 1; width <= 24; width++)
    for (var height = 1; height <= 24; height++)
      if (width != height &&
          (width.isOdd || height.isOdd) &&
          max(width, height) <= 4 * min(width, height))
        [width, height],
];
final _diameters = [
  for (var d = 1; d <= 20; d++) [d],
];
final _radii = [
  for (var r = 1; r <= 10; r++) [r],
];

/// Whole-number right triangles with sides up to 20, as (leg, leg,
/// longest side). The "sides at most 12" rule does not hold for these.
const _triples = [
  (3, 4, 5),
  (6, 8, 10),
  (5, 12, 13),
  (9, 12, 15),
  (8, 15, 17),
  (12, 16, 20),
];

/// The two legs of each triple, in both orders.
final _tripleLegs = [
  for (final (a, b, _) in _triples) ...[
    [a, b],
    [b, a],
  ],
];

/// Rectangles with the legs of a triple as sides, except 5 wide and 12
/// tall: on the compact card at text scale 2 its `?` leaves less than
/// 16 px of the diagonal showing.
final _diagonals = [
  for (final sides in _tripleLegs)
    if (sides[0] != 5 || sides[1] != 12) sides,
];

/// The longest side of the triple with legs [a] and [b].
int _longest(int a, int b) =>
    _triples.firstWhere((t) => {t.$1, t.$2}.containsAll({a, b})).$3;

/// Two crossing lines: the given angle 20° to 160°, and whether the asked
/// angle is its neighbour (1) or the one opposite it (0).
final _crossing = [
  for (var a = 20; a <= 160; a++)
    for (final neighbour in [0, 1]) [a, neighbour],
];

/// Three angles around a point, each 20° to 170° in steps of 5°; the
/// first two are given. (Four rays leave rays shorter than 16 px on the
/// compact card at text scale 2, so there are none.)
final _around = [
  for (var a = 20; a <= 170; a += 5)
    for (var b = 20; b <= 170; b += 5)
      if (360 - a - b case final c when c >= 20 && c <= 170) [a, b],
];

/// A triangle's inside angles a and b (as for [_triangleAngles]) and the
/// form: 0 asks the outside angle, 1 the angle b from a and the outside
/// angle. The outside angle a + b is 75° to 160°: in a narrower one its
/// label does not fit between its two lines clear of the other labels on
/// a short card at large text.
final _exterior = [
  for (final [a, b] in _triangleAngles)
    if (a + b >= 75)
      for (final form in [0, 1]) [a, b, form],
];

/// An isosceles triangle: the top angle 32° to 140° with a base angle
/// asked (form 0; even, so the base angle is whole), or a base angle 20° to
/// 74° with the top angle asked (form 1). A sharper top makes the base
/// shorter than 16 px on a short card at large text.
final _isosceles = [
  for (var top = 32; top <= 140; top += 2) [top, 0],
  for (var base = 20; base <= 74; base++) [base, 1],
];

/// Three angles of a quadrilateral, in steps of 10°; each angle, also the
/// asked fourth, 20° to 160°. Left out are [quadrilateralsLeftOut].
final _quadrilateral = [
  for (var a = 20; a <= 160; a += 10)
    for (var b = 20; b <= 160; b += 10)
      for (var c = 20; c <= 160; c += 10)
        if (360 - a - b - c case final d
            when d >= 20 &&
                d <= 160 &&
                !quadrilateralsLeftOut.contains(_angleCode([a, b, c])))
          [a, b, c],
];

/// Angles in steps of 10° as letters, 20° as a to 160° as o: [20, 30, 160]
/// is "abo".
String _angleCode(List<int> angles) =>
    String.fromCharCodes([for (final a in angles) 97 + a ~/ 10 - 2]);

/// The quadrilaterals (their three given angles, see [_angleCode]) whose
/// four labels do not fit the compact card (248 by 150) at text scale 2:
/// with the side proportions chosen they overlap or leave a side shorter
/// than 16 px at every turn the layout tries. A test checks that each of
/// them still fails there, so the list is redone when the layout changes.
final quadrilateralsLeftOut = _leftOutCodes.split(' ').toSet();

const _leftOutCodes =
    'abo acn aco adn ado aen aeo afn afo agm agn ago ahk ahl ahm ahn '
    'aho aii aij aik ail aim ain aio aji ajj ajk ajl ajm ajn ajo akh '
    'aki akj akk akl akm akn ako alg alh ali alj alk all alm aln alo '
    'ame amf amg amh ami amj amk aml amm amn amo anf ang anh ani anj '
    'ank anl anm ann ano aof aoh aoj aol aom aoo ban bao bbm bfo bgm '
    'bgn bgo bhk bhl bhm bhn bho bii bij bik bil bim bin bio bji bjj '
    'bjk bjl bjm bjn bjo bkh bki bkj bkk bkl bkm bkn bko blg blh bli '
    'blj blk bll blm bln blo bmg bmh bmi bmj bmk bml bmm bmn bmo bnd '
    'bne bnf bng bnh bnk bnn bno bol bom bon cam can cao cck cgn chk '
    'chl chm chn cho cii cij cik cil cim cin cio cji cjj cjk cjl cjm '
    'cjn cjo ckh cki ckj ckk ckl ckm ckn cko clh cli clj clk cll clm '
    'cln clo cmi cnj cnk cnl cnm cnn coa coi coj cok col com dal dam '
    'dan dao dbk dbn dcj dck ddi dgm dgn dgo dhk dhl dhm dhn dho dii '
    'dij dik dil dim din dio dji djj djk djl djm djn djo dki dkj dkk '
    'dkl dkm dkn dko dlo dmi dmj dmk dml dmm dmn dni dnj dnk dnl dnm '
    'dog doh doi doj dok dol eak eal eam ean ebj ebk eci ecj eck ecm '
    'edi edj eff egf egm egn ego ehm ehn eho eie eif eih eii eij eik '
    'eil eim ein eio ejj ejk ejl ejm ejn ejo ekk ekl eli elj elk ell '
    'elm eln ema emi emj emk eml emm ena enb eng enh eni enj enk enl '
    'eoa eoe eof eog eoh eoi eoj eok faj fak fal fam fan fao fbi fbj '
    'fbk fbl fch fci fcj fck fcl fdg fdh fdi fdj fef fei ffe fff ffo '
    'fge fgf fgn fgo fhm fhn fho fie fij fik fil fim fin fio fjj fjl '
    'fjm fjn fjo fki fkj fkk fkl fkm fkn fli flj flk fll flm fma fmb '
    'fmg fmh fmi fmj fmk fml fna fnf fng fnh fni fnj fnk foa foe fof '
    'fog foh foi foj gai gaj gak gal gam gan gbh gbi gbj gbk gbl gbm '
    'gbn gcg gch gci gcj gck gcl gdf gdg gdh gdi gdj gdk geg geh gei '
    'gej gfg gfh gfi gfn gfo ggn ggo ghn gik gil gim gin gio gjj gjk '
    'gjl gjm gjn gkd gki gkj gkk gkl gkm gla glb gli glj glk gll gma '
    'gmb gmc gmf gmg gmh gmi gmj gmk gna gne gnf gng gnh gni gnj goa '
    'god goe gof gog goh goi hah hai haj hak hal ham han hao hbg hbh '
    'hbi hbj hbk hbl hbm hbn hcf hcg hch hci hcj hck hcl hcm hdg hdh '
    'hdi hdj hdk hdl heg heh hei hej hek hfg hfh hfi hfj hfo hgo hie '
    'hij hik hil him hin hji hjj hjk hjl hjm hka hkb hkc hkd hki hkj '
    'hkk hkl hla hlb hlc hld hlh hli hlj hlk hma hmb hmf hmg hmh hmi '
    'hmj hna hne hnf hng hnh hni hoa hod hoe hof hog hoh iag iah iai '
    'iaj iak ial iam ian iao ibf ibg ibh ibi ibj ibk ibl ibm ibn ice '
    'icf icg ich ici icj ick icl idd ide idf idg idh idi idj idk idl '
    'ieg ieh iei iej ieo ifg ifh ifi ifj ifo igj ihl ihm ihn iia iib '
    'iic iid iie iii iij iik iil iim ija ijd ijh iji ijj ijk ijl ika '
    'ikb ikc ikd ikf ikg ikh iki ikj ikk ila ilb ilc ild ile ilf ilg '
    'ilh ili ilj ima imb imd ime imf img imh imi ina inb ind ine inf '
    'ing inh ioa ioc iod ioe iof iog jaf jag jah jai jaj jak jal jam '
    'jan jao jbe jbf jbg jbh jbi jbj jbk jbl jbm jcd jce jcf jcg jch '
    'jci jcj jck jcl jcm jde jdf jdg jdh jdi jdj jdk jdn jdo jeg jeh '
    'jei jej jeo jgj jgk jgl jgm jgn jha jhh jhj jhk jhl jhm jia jib '
    'jic jid jie jif jih jii jij jik jil jja jjb jjc jjd jje jjg jjh '
    'jji jjj jjk jka jkb jkc jkd jkf jkg jkh jki jkj jla jlb jlc jle '
    'jlf jlg jlh jli jma jmb jmd jme jmf jmg jmh jna jnd jne jnf jng '
    'joa joc jod joe jof kae kaf kag kah kai kaj kak kal kam kan kao '
    'kbd kbe kbf kbg kbh kbi kbj kbk kbl kbm kce kcf kcg kch kci kcj '
    'kck kcl kdg kdh kdi kdj kdk kei kej kem ken keo kfl kfm kfn kga '
    'kgj kgk kgl kgm kha khc khd khj khk khl kia kib kic kid kie kif '
    'kih kii kij kik kja kjb kjc kjd kje kjf kjg kjh kji kjj kka kkb '
    'kkc kkd kke kkf kkg kkh kki kla klb klc kle klf klg klh kma kmb '
    'kmd kme kmf kmg kna knb knc knd kne knf koc kod koe lad lae laf '
    'lag lah lai laj lak lal lam lan lao lbc lbd lbe lbf lbg lbh lbi '
    'lbj lbk lbl lbm lbn lcf lcg lch lci lcj lck lcl lea lem len lfa '
    'lfk lfl lfm lga lgj lgk lgl lha lhb lhc lhd lhe lhi lhj lhk lia '
    'lib lic lid lie lif lig lih lii lij lja ljb ljc ljd lje ljf ljg '
    'ljh lji lka lkb lkc lkd lke lkf lkg lkh lla llb llc lld lle llf '
    'llg lma lmb lmd lme lmf lna lnc lnd lne loa lob loc lod mac mad '
    'mae maf mag mah mai maj mak mal mam man mbb mbc mbf mbg mbh mbi '
    'mbj mbk mbl mbm mca mck mda mdl mdn mea mek mel mem mfa mfk mfl '
    'mga mgf mgj mgk mha mhb mhc mhd mhe mhf mhi mhj mia mib mic mid '
    'mie mif mig mih mii mja mjb mjc mjd mje mjg mjh mka mkb mkc mkd '
    'mkf mkg mla mlb mlc mld mle mlf mma mmb mmd mme mna mnc mnd mob '
    'moc nab nac nad nae naf nag nah nai naj nak nal nam nan nbk nbl '
    'nca nda ndl ndm nea nek nel nfa nfg nfk nga ngb ngc ngd nge ngf '
    'ngg ngi ngj nha nhb nhc nhd nhe nhf nhh nhi nia nib nic nid nie '
    'nif nig nih nja njb njc njd nje njf njg nka nkb nkc nkd nkf nla '
    'nlb nlc nld nle nma nmb nmd nna nnc noa nob oae oaf oag oah oai '
    'oaj oal oba oca oda odj odl oea oei ofa ofb off ofg ofh ofj oga '
    'ogb ogc ogd oge ogf ogg oha ohb ohc ohd ohe ohf ohg oia oib oic '
    'oid oie oig oja ojb ojc ojd oje ojf oka okb okc okd ola olb olc '
    'old oma omb omc ona onb ooa';

List<List<int>> _squareSpace() => _squares;
List<List<int>> _rectangleSpace() => _rectangles;
List<List<int>> _triangleSpace() => _triangles;
List<List<int>> _areaSpace() => _areas;
List<List<int>> _triangleAngleSpace() => _triangleAngles;
List<List<int>> _straightSpace() => _straight;
List<List<int>> _rightSpace() => _right;
List<List<int>> _legSpace() => _legs;
List<List<int>> _lShapeSpace() => _lShapes;
List<List<int>> _halvesSpace() => _halves;
List<List<int>> _diameterSpace() => _diameters;
List<List<int>> _radiusSpace() => _radii;
List<List<int>> _tripleLegSpace() => _tripleLegs;
List<List<int>> _diagonalSpace() => _diagonals;
List<List<int>> _crossingSpace() => _crossing;
List<List<int>> _aroundSpace() => _around;
List<List<int>> _exteriorSpace() => _exterior;
List<List<int>> _isoscelesSpace() => _isosceles;
List<List<int>> _quadrilateralSpace() => _quadrilateral;

/// A rectangle with its top-left corner at the origin; edge 1 is the
/// right side, edge 2 the bottom.
List<Offset> _box(num width, num height) => [
  Offset.zero,
  Offset(width.toDouble(), 0),
  Offset(width.toDouble(), height.toDouble()),
  Offset(0, height.toDouble()),
];

FigureQuestion _squarePerimeter(List<int> params) {
  _require(params.length == 1 && _readable(params[0], params[0]), params);
  final side = params[0];
  return (
    figure: Figure(
      shape: FigureShape.square,
      vertices: _box(side, side),
      labels: [SideLabel(2, side * 100)],
      prompt: FigurePrompt.perimeter,
    ),
    answer: 4 * side * 100,
  );
}

FigureQuestion _rectanglePerimeter(List<int> params) {
  _require(
    params.length == 2 &&
        params[0] != params[1] &&
        _readable(params.reduce(min), params.reduce(max)),
    params,
  );
  final [width, height] = params;
  return (
    figure: Figure(
      shape: FigureShape.rectangle,
      vertices: _box(width, height),
      labels: [SideLabel(2, width * 100), SideLabel(1, height * 100)],
      prompt: FigurePrompt.perimeter,
    ),
    answer: 2 * (width + height) * 100,
  );
}

/// The base is the longest side and the left side the shortest, so each
/// triangle appears once. Every angle is at least 20°, the longest side at
/// most 4 times the shortest, and the triangle inequality is strict.
bool _validTriangle(int base, int left, int right) {
  if (left < 2 || left > right || right > base || base > 12) return false;
  if (left + right <= base || base > 4 * left) return false;
  // The smallest angle is opposite the shortest side, the left one.
  final cosSmallest =
      (base * base + right * right - left * left) / (2 * base * right);
  return cosSmallest <= cos(20 * pi / 180);
}

FigureQuestion _trianglePerimeter(List<int> params) {
  _require(
    params.length == 3 && _validTriangle(params[0], params[1], params[2]),
    params,
  );
  final [base, left, right] = params;
  // The apex lies [left] from the bottom-left corner and [right] from the
  // bottom-right one.
  final x = (base * base + left * left - right * right) / (2 * base);
  final apex = Offset(x, -sqrt(left * left - x * x));
  return (
    figure: Figure(
      shape: FigureShape.triangle,
      vertices: [Offset.zero, apex, Offset(base.toDouble(), 0)],
      labels: [
        SideLabel(0, left * 100),
        SideLabel(1, right * 100),
        SideLabel(2, base * 100),
      ],
      prompt: FigurePrompt.perimeter,
    ),
    answer: (base + left + right) * 100,
  );
}

FigureQuestion _rectangleArea(List<int> params) {
  _require(
    params.length == 2 &&
        params.every((side) => side <= 10) &&
        _readable(params.reduce(min), params.reduce(max)),
    params,
  );
  final [width, height] = params;
  return (
    figure: Figure(
      shape: FigureShape.rectangle,
      vertices: _box(width, height),
      labels: [SideLabel(2, width * 100), SideLabel(1, height * 100)],
      prompt: FigurePrompt.area,
      grid: true,
    ),
    answer: width * height * 100,
  );
}

/// A square with a `?` on its bottom side and its perimeter or area given.
FigureQuestion _squareSide(List<int> params, {required bool fromArea}) {
  _require(params.length == 1 && _readable(params[0], params[0]), params);
  final side = params[0];
  return (
    figure: Figure(
      shape: FigureShape.square,
      vertices: _box(side, side),
      labels: const [SideLabel(2, null)],
      prompt: fromArea
          ? FigurePrompt.sideFromArea
          : FigurePrompt.sideFromPerimeter,
      total: (fromArea ? side * side : 4 * side) * 100,
    ),
    answer: side * 100,
  );
}

FigureQuestion _squareSideFromPerimeter(List<int> params) =>
    _squareSide(params, fromArea: false);

FigureQuestion _squareSideFromArea(List<int> params) =>
    _squareSide(params, fromArea: true);

/// A rectangle with its bottom side labelled, a `?` on its right side and
/// its perimeter or area given.
FigureQuestion _rectangleSide(List<int> params, {required bool fromArea}) {
  _require(
    params.length == 2 &&
        params[0] != params[1] &&
        _readable(params.reduce(min), params.reduce(max)),
    params,
  );
  final [width, height] = params;
  return (
    figure: Figure(
      shape: FigureShape.rectangle,
      vertices: _box(width, height),
      labels: [SideLabel(2, width * 100), const SideLabel(1, null)],
      prompt: fromArea
          ? FigurePrompt.sideFromArea
          : FigurePrompt.sideFromPerimeter,
      total: (fromArea ? width * height : 2 * (width + height)) * 100,
    ),
    answer: height * 100,
  );
}

FigureQuestion _rectangleSideFromPerimeter(List<int> params) =>
    _rectangleSide(params, fromArea: false);

FigureQuestion _rectangleSideFromArea(List<int> params) =>
    _rectangleSide(params, fromArea: true);

Offset _direction(int degrees) {
  final radians = degrees * pi / 180;
  // Counterclockwise on screen, where y points down.
  return Offset(cos(radians), -sin(radians));
}

/// A triangle with its base from the origin to (10, 0), the angle a at
/// the origin and b at the other end of the base (law of sines: the side
/// from the origin is opposite the angle b).
List<Offset> _triangleWithAngles(int a, int b) {
  const base = 10.0;
  final left = base * sin(b * pi / 180) / sin((a + b) * pi / 180);
  return [Offset.zero, _direction(a) * left, const Offset(base, 0)];
}

/// The turn that brings the longest side of the convex shape [corners] to
/// the bottom, with the shape above it, where it fits a wide card best.
Offset Function(Offset) _longestDown(List<Offset> corners) {
  final count = corners.length;
  var longest = 0;
  for (var i = 1; i < count; i++) {
    if ((corners[(i + 1) % count] - corners[i]).distance >
        (corners[(longest + 1) % count] - corners[longest]).distance) {
      longest = i;
    }
  }
  final from = corners[longest];
  final along = corners[(longest + 1) % count] - from;
  Offset turn(Offset v, double by) =>
      Offset(v.dx * cos(by) - v.dy * sin(by), v.dx * sin(by) + v.dy * cos(by));
  var by = -atan2(along.dy, along.dx);
  // Another corner above the longest side, with y down.
  if (turn(corners[(longest + 2) % count] - from, by).dy > 0) by += pi;
  return (v) => turn(v - from, by);
}

/// A triangle with the angles a at corner 0 and b at corner 2; the angle
/// at corner 1 is asked. It is turned so its longest side lies at the
/// bottom.
FigureQuestion _triangleAngle(List<int> params) {
  _require(_inSpace(_triangleAngles, params), params);
  final [a, b] = params;
  final corners = _triangleWithAngles(a, b);
  final turn = _longestDown(corners);
  return (
    figure: Figure(
      shape: FigureShape.triangle,
      vertices: [for (final c in corners) turn(c)],
      labels: const [],
      angles: [AngleLabel(0, a), const AngleLabel(1, null), AngleLabel(2, b)],
      prompt: FigurePrompt.angle,
    ),
    answer: (180 - a - b) * 100,
  );
}

/// Rays from the origin at 0°, a° and [whole]°; the angle a is given, the
/// rest of the whole is asked.
FigureQuestion _splitAngle(List<int> params, int whole, FigureShape shape) {
  final a = params.single;
  return (
    figure: Figure(
      shape: shape,
      vertices: [Offset.zero, _direction(0), _direction(a), _direction(whole)],
      labels: const [],
      angles: [AngleLabel(1, a), const AngleLabel(2, null)],
      prompt: FigurePrompt.angle,
    ),
    answer: (whole - a) * 100,
  );
}

FigureQuestion _straightAngle(List<int> params) {
  _require(_inSpace(_straight, params), params);
  return _splitAngle(params, 180, FigureShape.straightAngle);
}

FigureQuestion _rightAngle(List<int> params) {
  _require(_inSpace(_right, params), params);
  return _splitAngle(params, 90, FigureShape.rightAngle);
}

/// Legs a (bottom) and b (left), the right angle at the bottom-left
/// corner, the hypotenuse without a number.
FigureQuestion _rightTriangleArea(List<int> params) {
  _require(_inSpace(_legs, params), params);
  final [a, b] = params;
  return (
    figure: Figure(
      shape: FigureShape.rightTriangle,
      vertices: [
        Offset.zero,
        Offset(0, -b.toDouble()),
        Offset(a.toDouble(), 0),
      ],
      labels: [SideLabel(0, b * 100), SideLabel(2, a * 100)],
      prompt: FigurePrompt.area,
    ),
    answer: a * b * 50,
  );
}

/// The L-shape's corners from the top-left one, clockwise on screen: the
/// top edge, the inner vertical one, the inner horizontal one, the right
/// edge, the bottom and the left edge. Labelled: the top, the inner
/// horizontal, the left and the right edge.
Figure _lShape(List<int> params, FigurePrompt prompt) {
  final [width, height, cutWidth, cutHeight] = params;
  final top = width - cutWidth;
  return Figure(
    shape: FigureShape.lShape,
    vertices: [
      Offset.zero,
      Offset(top.toDouble(), 0),
      Offset(top.toDouble(), cutHeight.toDouble()),
      Offset(width.toDouble(), cutHeight.toDouble()),
      Offset(width.toDouble(), height.toDouble()),
      Offset(0, height.toDouble()),
    ],
    labels: [
      SideLabel(0, top * 100),
      SideLabel(2, cutWidth * 100),
      SideLabel(3, (height - cutHeight) * 100),
      SideLabel(5, height * 100),
    ],
    prompt: prompt,
  );
}

FigureQuestion _lShapePerimeter(List<int> params) {
  _require(_inSpace(_lShapes, params), params);
  final [width, height, _, _] = params;
  return (
    figure: _lShape(params, FigurePrompt.perimeter),
    answer: 2 * (width + height) * 100,
  );
}

FigureQuestion _lShapeArea(List<int> params) {
  _require(_inSpace(_lShapes, params), params);
  final [width, height, cutWidth, cutHeight] = params;
  return (
    figure: _lShape(params, FigurePrompt.area),
    answer: (width * height - cutWidth * cutHeight) * 100,
  );
}

Figure _halvesRectangle(List<int> params, FigurePrompt prompt) {
  final [width, height] = params;
  return Figure(
    shape: FigureShape.rectangle,
    vertices: _box(width / 2, height / 2),
    labels: [SideLabel(2, width * 50), SideLabel(1, height * 50)],
    prompt: prompt,
  );
}

FigureQuestion _halvesRectanglePerimeter(List<int> params) {
  _require(_inSpace(_halves, params), params);
  final [width, height] = params;
  return (
    figure: _halvesRectangle(params, FigurePrompt.perimeter),
    answer: (width + height) * 100,
  );
}

FigureQuestion _halvesRectangleArea(List<int> params) {
  _require(_inSpace(_halves, params), params);
  final [width, height] = params;
  // Half units times half units are quarters: 25 hundredths each.
  return (
    figure: _halvesRectangle(params, FigurePrompt.area),
    answer: width * height * 25,
  );
}

/// A circle of diameter [d] with its diameter drawn upright, so its label
/// (taller than wide) fits beside it.
FigureQuestion _circleCircumference(List<int> params) {
  _require(_inSpace(_diameters, params), params);
  final [d] = params;
  final r = d / 2;
  return (
    figure: Figure(
      shape: FigureShape.circle,
      vertices: [Offset(0, -r), Offset(0, r)],
      labels: [SideLabel(0, d * 100)],
      prompt: FigurePrompt.circumference,
      centre: Offset.zero,
      pi: piHundredths,
    ),
    answer: piHundredths * d,
  );
}

/// A circle of radius [r] with a radius drawn from the centre.
FigureQuestion _circleArea(List<int> params) {
  _require(_inSpace(_radii, params), params);
  final [r] = params;
  return (
    figure: Figure(
      shape: FigureShape.circle,
      vertices: [Offset.zero, Offset(r.toDouble(), 0)],
      labels: [SideLabel(0, r * 100)],
      prompt: FigurePrompt.area,
      centre: Offset.zero,
      pi: piHundredths,
    ),
    answer: piHundredths * r * r,
  );
}

/// Two straight lines crossing at the origin, one along the x axis, the
/// other at a°. The angle a is given; the one opposite it or its neighbour
/// is asked.
FigureQuestion _verticallyOppositeAngles(List<int> params) {
  _require(_inSpace(_crossing, params), params);
  final [a, neighbour] = params;
  return (
    figure: Figure(
      shape: FigureShape.crossingLines,
      vertices: [
        Offset.zero,
        _direction(0),
        _direction(a),
        _direction(180),
        _direction(180 + a),
      ],
      labels: const [],
      angles: [AngleLabel(1, a), AngleLabel(neighbour == 1 ? 2 : 3, null)],
      prompt: FigurePrompt.angle,
    ),
    answer: (neighbour == 1 ? 180 - a : a) * 100,
  );
}

/// Rays from the origin at 0° and after each given angle; the last angle,
/// back to the first ray, is asked.
FigureQuestion _anglesAroundPoint(List<int> params) {
  _require(_inSpace(_around, params), params);
  var turned = 0;
  final directions = [
    _direction(0),
    for (final a in params) _direction(turned += a),
  ];
  return (
    figure: Figure(
      shape: FigureShape.aroundPoint,
      vertices: [Offset.zero, ...directions],
      labels: const [],
      angles: [
        for (final (i, a) in params.indexed) AngleLabel(i + 1, a),
        AngleLabel(params.length + 1, null),
      ],
      prompt: FigurePrompt.angle,
    ),
    answer: (360 - turned) * 100,
  );
}

/// A right triangle drawn like [_rightTriangleArea]: legs a (bottom) and
/// b (left), the right angle at the bottom-left corner.
List<Offset> _rightCorners(int a, int b) => [
  Offset.zero,
  Offset(0, -b.toDouble()),
  Offset(a.toDouble(), 0),
];

/// Legs a (bottom) and b (left) given, the longest side asked.
FigureQuestion _pythagorasHypotenuse(List<int> params) {
  _require(_inSpace(_tripleLegs, params), params);
  final [a, b] = params;
  return (
    figure: Figure(
      shape: FigureShape.rightTriangle,
      vertices: _rightCorners(a, b),
      labels: [
        SideLabel(2, a * 100),
        SideLabel(0, b * 100),
        const SideLabel(1, null),
      ],
      prompt: FigurePrompt.length,
    ),
    answer: _longest(a, b) * 100,
  );
}

/// The bottom leg a and the longest side given, the left leg b asked.
FigureQuestion _pythagorasLeg(List<int> params) {
  _require(_inSpace(_tripleLegs, params), params);
  final [a, b] = params;
  return (
    figure: Figure(
      shape: FigureShape.rightTriangle,
      vertices: _rightCorners(a, b),
      labels: [
        SideLabel(2, a * 100),
        const SideLabel(0, null),
        SideLabel(1, _longest(a, b) * 100),
      ],
      prompt: FigurePrompt.length,
    ),
    answer: b * 100,
  );
}

/// A rectangle with its bottom and right sides labelled and its diagonal
/// from the top-left to the bottom-right corner asked.
FigureQuestion _rectangleDiagonal(List<int> params) {
  _require(_inSpace(_diagonals, params), params);
  final [width, height] = params;
  return (
    figure: Figure(
      shape: FigureShape.rectangle,
      vertices: _box(width, height),
      labels: [SideLabel(2, width * 100), SideLabel(1, height * 100)],
      prompt: FigurePrompt.length,
      diagonal: true,
    ),
    answer: _longest(width, height) * 100,
  );
}

/// A triangle with the inside angles a and b, standing on the side across
/// from the larger of them (so the triangle lies flat). Corner 0 has the
/// larger of a and b, corner 1 the smaller, corner 2 the rest; the side
/// from corner 0 to corner 2 is drawn on past corner 2, so the outside
/// angle there borders the long side, away from the other labels. Form 0
/// asks the outside angle (a + b), form 1 the angle b from a and the
/// outside angle.
FigureQuestion _exteriorAngle(List<int> params) {
  _require(_inSpace(_exterior, params), params);
  final [a, b, form] = params;
  final (atA, atB) = a > b ? (0, 1) : (1, 0);
  final [small, large, c2] = _triangleWithAngles(min(a, b), 180 - a - b);
  final along = c2 - large;
  return (
    figure: Figure(
      shape: FigureShape.triangle,
      vertices: [large, small, c2],
      labels: const [],
      angles: [
        AngleLabel(atA, a),
        AngleLabel(atB, form == 0 ? b : null),
        AngleLabel(3, form == 0 ? null : a + b),
      ],
      prompt: FigurePrompt.angle,
      // Half as long as the base.
      extension: c2 + along / along.distance * 5,
    ),
    answer: (form == 0 ? a + b : b) * 100,
  );
}

/// An isosceles triangle standing on its base, the top at corner 1 and a
/// tick on each of the two equal sides. Form 0 gives the top angle and asks
/// the base angle at corner 0; form 1 gives that base angle and asks the
/// top angle.
FigureQuestion _isoscelesTriangle(List<int> params) {
  _require(_inSpace(_isosceles, params), params);
  final [angle, form] = params;
  final base = form == 0 ? (180 - angle) ~/ 2 : angle;
  final top = 180 - 2 * base;
  return (
    figure: Figure(
      shape: FigureShape.triangle,
      vertices: [
        Offset.zero,
        Offset(5, -5 * tan(base * pi / 180)),
        const Offset(10, 0),
      ],
      labels: const [],
      angles: form == 0
          ? [AngleLabel(1, top), const AngleLabel(0, null)]
          : [AngleLabel(0, base), const AngleLabel(1, null)],
      prompt: FigurePrompt.angle,
      ticks: const [0, 1],
    ),
    answer: (form == 0 ? base : top) * 100,
  );
}

/// A convex quadrilateral with the angles a, b and c at corners 0 to 2;
/// the angle at corner 3 is asked.
FigureQuestion _quadrilateralAngles(List<int> params) {
  _require(_inSpace(_quadrilateral, params), params);
  final [a, b, c] = params;
  return (
    figure: Figure(
      shape: FigureShape.quadrilateral,
      vertices: quadrilateralCorners(a, b, c),
      labels: const [],
      angles: [
        AngleLabel(0, a),
        AngleLabel(1, b),
        AngleLabel(2, c),
        const AngleLabel(3, null),
      ],
      prompt: FigurePrompt.angle,
    ),
    answer: (360 - a - b - c) * 100,
  );
}

/// The corners of a convex quadrilateral with the angles a, b and c at
/// corners 0 to 2 and the rest of 360° at corner 3. Its sides are chosen
/// so the shortest side is as long as it can be next to the shape's
/// thinnest width, so it still shows when the shape is drawn flat on a
/// short card; it is turned so its longest side lies at the bottom.
List<Offset> quadrilateralCorners(int a, int b, int c) {
  final d = 360 - a - b - c;
  // Edge i leaves corner i; at each next corner the outline turns by 180°
  // minus the angle there.
  final directions = [_direction(0)];
  var heading = 0;
  for (final angle in [b, c, d]) {
    directions.add(_direction(heading += 180 - angle));
  }
  final [u0, u1, u2, u3] = directions;
  final det = u2.dx * u3.dy - u2.dy * u3.dx;
  List<Offset>? best;
  var bestRatio = double.infinity;
  // The first side 10 long; the second picked from 2 to 40, the last two
  // then close the shape.
  for (var step = 4; step <= 80; step++) {
    final lengths = [10.0, step / 2];
    final rest = -(u0 * lengths[0] + u1 * lengths[1]);
    lengths
      ..add((rest.dx * u3.dy - rest.dy * u3.dx) / det)
      ..add((u2.dx * rest.dy - u2.dy * rest.dx) / det);
    if (lengths.any((length) => length <= 0)) continue;
    final corners = [Offset.zero];
    for (var i = 0; i < 3; i++) {
      corners.add(corners.last + directions[i] * lengths[i]);
    }
    // The thinnest width: across from some side, its farthest corner.
    final thinnest = [
      for (var i = 0; i < 4; i++)
        [
          for (final corner in corners)
            _distanceToLine(corner, corners[i], corners[(i + 1) % 4]),
        ].reduce(max),
    ].reduce(min);
    final ratio = thinnest / lengths.reduce(min);
    if (ratio < bestRatio) {
      bestRatio = ratio;
      best = corners;
    }
  }
  final turn = _longestDown(best!);
  return [for (final corner in best) turn(corner)];
}

/// The distance from [p] to the line through [a] and [b].
double _distanceToLine(Offset p, Offset a, Offset b) {
  final ab = b - a;
  return ((p - a).dx * ab.dy - (p - a).dy * ab.dx).abs() / ab.distance;
}
