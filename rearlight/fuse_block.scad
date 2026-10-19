// Copy of black fuse/stud block half. 105 x 26 x 8 mm.
// Open tray: inside face open at z=0 in part() (rim + gutter + bosses), flat outside face at z=H.
L = 105; W = 26; H = 8;
// End shape: one long diagonal + one short steep chamfer; far end is the mirror image
long_dx = 12; long_dy = 18; short_dx = 6; short_dy = 2.5;
rim = 2; gutter = 2; inner_wall = 1.2; floor_t = 2; boss_top = 2;
stud_d = 6.4; stud_inset = 14; hex_af = 9; hex_depth = 3; stud_boss_d = 14;
screw_d = 4.5; screw_x = 27; screw_boss_d = 9;
clip_l = 14; clip_w = 4; clip_left = 1; // 4 blind clip recesses beside the screw holes
cable_d = 5;

fz = H - floor_t;
module outline() {
  e = [[L-long_dx,0],[L,long_dy],[L,W-short_dy],[L-short_dx,W]];
  f = [for (i = [len(e)-1:-1:0]) [L-e[i][0], e[i][1]]];
  polygon(concat(e, f));
}
studs  = [[stud_inset, W/2], [L-stud_inset, W/2]];
screws = [[screw_x, W/2], [L-screw_x, W/2]];

module part() difference() {
  union() {
    difference() {
      linear_extrude(H) outline();
      translate([0,0,-1]) linear_extrude(fz+1) offset(delta=-rim) outline();
    }
    // low inner wall (gutter lies between it and the rim)
    translate([0,0,boss_top]) linear_extrude(fz-boss_top+0.01)
      difference() { offset(delta=-(rim+gutter)) outline();
                     offset(delta=-(rim+gutter+inner_wall)) outline(); }
    for (p = studs)  translate([p[0],p[1],boss_top]) cylinder(d=stud_boss_d,h=fz-boss_top+0.01,$fn=48);
    for (p = screws) translate([p[0],p[1],boss_top]) cylinder(d=screw_boss_d,h=fz-boss_top+0.01,$fn=48);
  }
  for (p = studs) {
    translate([p[0],p[1],boss_top-1]) cylinder(d=hex_af/cos(30),h=hex_depth+1,$fn=6);
    translate([p[0],p[1],-1]) cylinder(d=stud_d,h=H+2,$fn=48);
  }
  for (p = screws) translate([p[0],p[1],-1]) cylinder(d=screw_d,h=H+2,$fn=32);
  translate([L/2,W/2,-1]) cylinder(d=cable_d,h=H+2,$fn=48);
  for (p = screws, y = [rim, W-rim-clip_w])
    translate([p[0]-clip_l/2,y,-1]) cube([clip_l,clip_w,H-clip_left+1]);
}

// Flipped for printing: flat outside face on the bed, open tray facing up.
translate([0,W,H]) rotate([180,0,0]) part();
