// Copy of black fuse/stud block half. 105 x 28 x 8 mm.
// Open tray: inside face open at z=0 in part() (rim + gutter + bosses), flat outside face at z=H.
L = 105; W = 28; H = 8;
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
// corner radii fitted to the original: A = long diagonal / narrow edge, N = nose, D = chamfer / wide edge
r_A = 4.5; r_N = 3.7; r_D = 7.3;

fz = H - floor_t;
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
    for (p = studs)  translate([p[0],p[1],boss_top]) cylinder(d=stud_boss_d,h=fz-boss_top+0.01,$fn=48);
    for (p = screws) translate([p[0],p[1],screw_top]) cylinder(d=screw_boss_d,h=fz-screw_top+0.01,$fn=48);
  }
  for (p = studs) {
    translate([p[0],p[1],boss_top-1]) cylinder(d=hex_af/cos(30),h=hex_depth+1,$fn=6);
    translate([p[0],p[1],-1]) cylinder(d=stud_d,h=H+2,$fn=48);
  }
  // screw holes: narrow shaft on the inside, 90-degree countersink then a straight bore of cs_d up to the outside face (z=H)
  for (p = screws) {
    translate([p[0],p[1],-1]) cylinder(d=screw_d,h=H+2,$fn=32);
    translate([p[0],p[1],H-cs_depth]) cylinder(d1=screw_d,d2=cs_d,h=cs_cone+0.001,$fn=48);
    translate([p[0],p[1],H-cs_depth+cs_cone]) cylinder(d=cs_d,h=cs_depth-cs_cone+1,$fn=48);
  }
  translate([L/2,hole_y,-1]) cylinder(d=cable_d,h=H+2,$fn=48);
  for (p = screws, y = [rim, W-rim-clip_w])
    translate([p[0]+(p[0]<L/2 ? clip_shift : -clip_shift)-clip_l/2,y,-1]) cube([clip_l,clip_w,H-clip_left+1]);
}

// Flipped for printing: flat outside face on the bed, open tray facing up.
translate([0,W,H]) rotate([180,0,0]) part();
