// Variant of fuse_block.scad: no cable hole through the floor. The cable comes up from the light at the
// old hole position, turns through a 90-degree bend inside a deeper tray, and leaves through the edge wall.
// Everything is measured from the open face (z=0), so the mating part sees exactly the same tray as fuse_block
// down to z=8; the floor is simply extra_depth lower, which makes the walls, inner wall and pillars taller.
// Open tray: inside face open at z=0 in part() (rim + gutter + bosses), flat outside face at z=H.
L = 105; W = 28;
// original tray depth; the mating part sees this much of the tray exactly as in fuse_block
H0 = 8;
// how much deeper the tray is than fuse_block (screws and studs must be this much longer)
extra_depth = 12;
H = H0 + extra_depth;
// cable exit: true = bent channel out of the edge wall, false = the original straight hole through the floor
cable_exit = true;
// which edge the cable leaves by: -1 = narrow edge (y=0, the "bottom"), 1 = wide edge (y=W, the "top")
exit_dir = -1;
// bend radius of the cable centre line; this is also the height of the exit below the open face, so a smaller value
// moves the exit up, away from the base of the tray. Keep it at 9.75 or more so the bore does not run into the thin
// skin just under the top of the gutter fill (bore top = bend_r - cable_bore/2 must be at least 1 mm below gutter_fill_top)
bend_r = 10;
// extra clearance in the bore
cable_clear = 0.5;
// cable clamp: a slit gland sticking out of the exit wall; a zip tie in its groove squeezes it onto the cable
cable_clamp = true;
// length of the gland beyond the wall, and its diameter (its lower half is filled down to the outside face so it prints without supports)
clamp_len = 14;
clamp_d = 10;
// false = the gland is a plain round tube, clear of the outside face (needs supports when printing);
// true = its lower half is filled flat down to the outside face so it prints without supports
clamp_flat_base = false;
// radius that rounds the edges of the free end of the gland (0 = square end), and the width of the flared cable entry
clamp_round = 1.5;
clamp_flare = 1.0;
// width of the slit that lets the two halves close, zip tie width, and groove depth
clamp_slit = 1.0;
tie_w = 3.2;
tie_depth = 1.2;
// End shape: one long diagonal + one short steep chamfer; far end is the mirror image
long_dx = 12.97; nose_out = 1.92; nose_y = 18.82; short_dx = 4.93;  // end shape fitted to a trace of the original (nose is nose_out beyond x=0)
rim = 1.2; gutter = 2.8; inner_wall = 1.2; floor_t = 2; boss_top = 2;
// heights of the tops of the inner wall and screw pillars, measured from the open face (z=0): the mating part slips this far in
wall_top = 4; screw_top = 4;
// rim+gutter = 4 mm: inner wall unchanged; rim is 3 perimeters of a 0.4 mm nozzle (original design was rim = 2)
// stud_inset = distance of each stud from its end (x=0 / x=L); larger moves it toward the screw holes (screws at screw_x = 27)
stud_d = 6.4; stud_inset = 15.25; hex_af = 8; hex_depth = 3; stud_boss_d = 14;
// stud_dy shifts the studs from the hole line toward the wide edge (keeps the stud bosses clear of the inner wall on the diagonal side)
stud_dy = 1.5;
screw_d = 4.0; screw_x = 27; screw_boss_d = 9;
cs_d = 8; cs_depth = 4;  // countersink opening width and total depth from outside face
cs_cone = (cs_d - screw_d)/2; // 90-degree cone height; straight bore of cs_d fills the rest of cs_depth
clip_l = 14; clip_w = 4; clip_left = 1; clip_shift = 2; // clip recesses shifted this far toward the piece centre // 4 blind clip recesses beside the screw holes
cable_d = 5;
cable_bore = cable_d + cable_clear;
clip_depth = H0 - clip_left;
// corner radii fitted to the original: A = long diagonal / narrow edge, N = nose, D = chamfer / wide edge
r_A = 4.5; r_N = 3.7; r_D = 7.3;

fz = H - floor_t;
// floor of the original shallow tray: the screw heads and pillar tops keep their original depth from the open face
fz0 = H0 - floor_t;
// the gutter between the rim and the inner wall is filled solid from the new floor up to this depth below the open face;
// the default is the original floor level, so the gutter is exactly as deep as in fuse_block (the slots still cut 1 mm into the fill)
gutter_fill_top = fz0;
// below fz0 the screw pillars widen to this diameter so the deep 8 mm screw well keeps a 2 mm wall
screw_boss_d2 = 12;
// true = stud hex pockets are also deepened by extra_depth, so the stud bolts keep their original length
stud_deep_pocket = false;
// true = the large stud bosses keep their original tops (boss_top) and run down to the new floor, so they are attached to the base of the tray;
// false = they stop at the old floor level and hang off the inner wall (needs supports when printing)
stud_boss_full = true;
// Stud/screw/cable centre line: 13.5 mm from the wide edge (y=W), 14.5 mm from the narrow edge (fitted to the original)
hole_y = W - 13.5;
// Rounded convex polygon: exact tangent arcs, each corner with its own radius (radii must fit their edges)
function unit(v) = v / norm(v);
function arc_pts(P, Q, R, r, n = 24) =
  let (u1 = unit(P - Q), u2 = unit(R - Q), half = acos(u1 * u2) / 2,
       c  = Q + unit(u1 + u2) * (r / sin(half)),
       t1 = Q + u1 * (r / tan(half)), t2 = Q + u2 * (r / tan(half)),
       a1 = atan2(t1[1] - c[1], t1[0] - c[0]), a2 = atan2(t2[1] - c[1], t2[0] - c[0]),
       da = ((a2 - a1 + 540) % 360) - 180)
  [for (k = [0:n]) c + r * [cos(a1 + da * k / n), sin(a1 + da * k / n)]];

module outline() {
  e = [[L-long_dx,0],[L+nose_out,nose_y],[L-short_dx,W]];
  f = [for (i = [len(e)-1:-1:0]) [L-e[i][0], e[i][1]]];
  pts = concat(e, f);
  rs  = [r_A, r_N, r_D, r_D, r_N, r_A];
  n = len(pts);
  polygon([for (i = [0:n-1]) each arc_pts(pts[(i+n-1)%n], pts[i], pts[(i+1)%n], rs[i])]);
}
studs  = [[stud_inset, hole_y + stud_dy], [L-stud_inset, hole_y + stud_dy]];
screws = [[screw_x, hole_y], [L-screw_x, hole_y]];

// Cable path: starts at the old hole position on the open face (z=0) heading deeper, bends through 90 degrees
// in the y-z plane and runs straight out through the edge wall at z = bend_r.
module cable_path() {
  y0 = hole_y;
  n  = 24;
  function pt(a) = [L/2, y0 + exit_dir * bend_r * (1 - cos(a)), bend_r * sin(a)];
  y_end = exit_dir > 0 ? W + 2 : -2;
  // short lead-in above the open face
  translate([L/2, y0, -2]) cylinder(d=cable_bore, h=2.01, $fn=32);
  // the 90-degree bend
  for (i = [0:n-1])
    hull() {
      translate(pt(90 * i / n))       sphere(d=cable_bore, $fn=24);
      translate(pt(90 * (i + 1) / n)) sphere(d=cable_bore, $fn=24);
    }
  // straight run out through the inner wall and the rim
  translate([L/2, y0 + exit_dir * bend_r, bend_r])
    rotate([exit_dir > 0 ? -90 : 90, 0, 0])
      cylinder(d=cable_bore, h=abs(y_end - (y0 + exit_dir * bend_r)), $fn=32);
}

// 2D section of the gland (x across the part, y = height z): a round tube whose lower half is filled
// down to the outside face
module clamp_profile() {
  translate([L/2, bend_r]) circle(d = clamp_d, $fn = 48);
  if (clamp_flat_base) translate([L/2 - clamp_d/2, bend_r]) square([clamp_d, H - bend_r]);
}
// maps (x, y, z) in the gland frame (x across, y = height, z = distance out of the wall) to the part
module to_exit() {
  multmatrix([[1, 0, 0, 0], [0, 0, exit_dir, exit_dir > 0 ? W : 0], [0, 1, 0, 0], [0, 0, 0, 1]]) children();
}
// the same section, but running clamp_round below the outside face so the rounded end can be trimmed flat
module clamp_profile_ext() {
  translate([L/2, bend_r]) circle(d = clamp_d, $fn = 48);
  if (clamp_flat_base) translate([L/2 - clamp_d/2, bend_r]) square([clamp_d, H - bend_r + 2 * clamp_round]);
}
module clamp_body() {
  if (clamp_round > 0) {
    // straight part, then a rounded end cap; the underside stays flat at the outside face
    to_exit() translate([0, 0, -1]) linear_extrude(clamp_len - clamp_round + 1) clamp_profile();
    to_exit() intersection() {
      translate([0, 0, clamp_len - clamp_round]) minkowski() {
        linear_extrude(0.01) offset(delta = -clamp_round) clamp_profile_ext();
        sphere(r = clamp_round, $fn = 24);
      }
      translate([L/2 - clamp_d, -5, -1]) cube([2 * clamp_d, H + 5, clamp_len + 2]);
    }
  } else {
    to_exit() translate([0, 0, -1]) linear_extrude(clamp_len + 1) clamp_profile();
  }
}
module clamp_cuts() {
  // bore for the cable (cable_d, so the closed gland grips it)
  to_exit() translate([L/2, bend_r, -2]) cylinder(d = cable_d, h = clamp_len + 4, $fn = 32);
  // flared entry at the free end, so the cable jacket meets a rounded mouth and not a sharp edge
  to_exit() translate([L/2, bend_r, clamp_len - clamp_flare]) cylinder(d1 = cable_d, d2 = cable_d + 2 * clamp_flare, h = clamp_flare + 0.01, $fn = 32);
  // slit from the free end back to 4 mm from the wall
  to_exit() translate([L/2 - clamp_slit/2, -1, 4]) cube([clamp_slit, H + 2, clamp_len]);
  // zip tie groove all round the gland, 3 mm from the free end
  to_exit() translate([0, 0, clamp_len - 3 - tie_w]) linear_extrude(tie_w)
    difference() { offset(delta = 1) clamp_profile(); offset(delta = -tie_depth) clamp_profile(); }
}

module part() difference() {
  union() {
    difference() {
      linear_extrude(H) outline();
      translate([0,0,-1]) linear_extrude(fz+1) offset(delta=-rim) outline();
    }
    // low inner wall (gutter lies between it and the rim)
    translate([0,0,wall_top]) linear_extrude(fz-wall_top+0.01)
      difference() { offset(delta=-(rim+gutter)) outline();
                     offset(delta=-(rim+gutter+inner_wall)) outline(); }
    if (fz > gutter_fill_top)
      translate([0,0,gutter_fill_top]) linear_extrude(fz - gutter_fill_top + 0.01)
        difference() { offset(delta=-rim) outline(); offset(delta=-(rim+gutter)) outline(); }
    for (p = studs)  translate([p[0],p[1],boss_top]) cylinder(d=stud_boss_d,h=(stud_boss_full ? fz : fz0)-boss_top+0.01,$fn=48);
    for (p = screws) translate([p[0],p[1],screw_top]) cylinder(d=screw_boss_d,h=fz0-screw_top+0.01,$fn=48);
    if (cable_exit && cable_clamp) clamp_body();
    if (fz > fz0)
      for (p = screws) translate([p[0],p[1],fz0]) cylinder(d=screw_boss_d2,h=fz-fz0+0.01,$fn=48);
  }
  for (p = studs) {
    translate([p[0],p[1],boss_top-1]) cylinder(d=hex_af/cos(30),h=hex_depth+1+(stud_deep_pocket ? extra_depth : 0),$fn=6);
    translate([p[0],p[1],-1]) cylinder(d=stud_d,h=H+2,$fn=48);
  }
  // screw holes: narrow shaft on the inside, 90-degree countersink then a straight bore of cs_d up to the outside face (z=H)
  for (p = screws) {
    translate([p[0],p[1],-1]) cylinder(d=screw_d,h=H+2,$fn=32);
    translate([p[0],p[1],H0-cs_depth]) cylinder(d1=screw_d,d2=cs_d,h=cs_cone+0.001,$fn=48);
    translate([p[0],p[1],H0-cs_depth+cs_cone]) cylinder(d=cs_d,h=H-(H0-cs_depth+cs_cone)+1,$fn=48);
  }
  if (cable_exit) cable_path();
  if (cable_exit && cable_clamp) clamp_cuts();
  else translate([L/2,hole_y,-1]) cylinder(d=cable_d,h=H+2,$fn=48);
  for (p = screws, y = [rim, W-rim-clip_w])
    translate([p[0]+(p[0]<L/2 ? clip_shift : -clip_shift)-clip_l/2,y,-1]) cube([clip_l,clip_w,clip_depth+1]);
}

// Flipped for printing: flat outside face on the bed, open tray facing up.
translate([0,W,H]) rotate([180,0,0]) part();
