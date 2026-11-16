"""Pure Delta V2 geometry regressions; no assembly, runtime or file writes."""
import sys
sys.dont_write_bytecode = True

import unittest

import assemble_delta_queen_spatial_candidate_v2 as recipe


class DeltaPerspectiveGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.edges = {y: (150,170,580,600) for y in range(363,460)}
        cls.proof = recipe.geometry_contract(cls.edges)

    def test_prior_constant_width_plane_cannot_return(self):
        rows = self.proof["target_felt_rows"]
        self.assertEqual(len(rows),118)
        self.assertEqual(rows[0]["logical_outer"],[124,676])
        self.assertEqual(rows[-1]["logical_outer"],[65,711])
        self.assertGreaterEqual(rows[0]["logical_outer"][0]-rows[-1]["logical_outer"][0],59)
        self.assertGreater(rows[-1]["visible_draw_half_open"][1]-rows[-1]["visible_draw_half_open"][0],
                           rows[0]["visible_draw_half_open"][1]-rows[0]["visible_draw_half_open"][0]+58)

    def test_far_and_near_edges_remain_different(self):
        self.assertEqual(recipe.fit_source(None,124,352,self.edges)[2],"far_rim")
        self.assertIsNone(recipe.fit_source(None,123,352,self.edges))
        self.assertEqual(recipe.fit_source(None,64,476,self.edges)[2],"near_rim")
        self.assertIsNone(recipe.fit_source(None,63,476,self.edges))

    def test_every_visible_side_row_uses_real_rail_in_eight_target_pixels(self):
        for y in range(358,476):
            left,right=recipe.top_bounds(y)
            samples=[recipe.fit_source(None,x,y,self.edges) for x in range(left,left+8)]
            self.assertTrue(all(row[2]=="left_rail_traced_material" for row in samples))
            self.assertTrue(all(150<=row[0]<170 for row in samples))
            self.assertEqual(sorted(row[0] for row in samples),[row[0] for row in samples])
            self.assertEqual(recipe.fit_source(None,left+8,y,self.edges)[2],"felt")

    def test_full_actual_generic_contact_rectangles_are_felt(self):
        for face in recipe.FACES:
            points=recipe.face_points(face)
            self.assertTrue(points)
            for x,y in points:
                self.assertEqual(recipe.fit_source(None,x,y,self.edges)[2],"felt")

    def test_selected_width_has_margin_without_wider44_overhang(self):
        comparisons={row["near_left_native"]:row for row in self.proof["near_left_comparison"]}
        self.assertEqual({key:value["minimum_BJ_left_pixel_margin_native"] for key,value in comparisons.items()},
                         {44:16,64:9,68:8,72:6,84:3})
        self.assertEqual(self.proof["largest_near_left_meeting8px_BJ_margin_native"],68)
        self.assertEqual(self.proof["selected_near_left_native"],64)
        self.assertEqual(self.proof["additional_safety_expansion_native"],4)
        self.assertEqual(comparisons[44]["near_expansion_from_V1_outer116_native"]-
                         comparisons[64]["near_expansion_from_V1_outer116_native"],20)

    def test_right_logical_rail_is_hidden_not_compressed(self):
        for y in range(358,476):
            left,right=recipe.top_bounds(y)
            self.assertGreater(right-8,660)
            self.assertEqual(recipe.fit_source(None,659,y,self.edges)[2],"felt")
            self.assertIsNone(recipe.fit_source(None,660,y,self.edges))
            self.assertIsNone(recipe.fit_source(None,right-1,y,self.edges))

    def test_fixed_right_cabinet_and_whole_right_master_are_protected(self):
        for y in range(0,860):
            for x in (660,661,800,1199,1200,1799):
                self.assertIsNone(recipe.fit_source(None,x,y,self.edges))

    def test_no_exposed_old_panel_corner_needs_wall_filling(self):
        for y in range(356,516):
            for x in range(128,604):
                self.assertIsNotNone(recipe.fit_source(None,x,y,self.edges))

    def test_no_architecture_or_lower_deck_mapping_outside_exact_bands(self):
        for y in (0,330,340,351,540,548,600,859):
            for x in range(0,660):
                self.assertIsNone(recipe.fit_source(None,x,y,self.edges))

    def test_complete_supports_attach_to_apron_inside_audited_zero_runs(self):
        self.assertEqual(recipe.POSTS,((200,516,56,24),(620,516,36,24)))
        for index,(x,y,w,h) in enumerate(recipe.POSTS):
            safe_left,safe_right=((194,278),(616,660))[index]
            self.assertGreaterEqual(x,safe_left)
            self.assertLessEqual(x+w,safe_right)
            self.assertEqual((y,y+h),(516,540))
            for xx in range(x,x+w):
                self.assertEqual(recipe.fit_source(None,xx,515,self.edges)[2],"quiet_apron")
                for yy in range(y,y+h):
                    self.assertTrue(recipe.fit_source(None,xx,yy,self.edges)[2].startswith(f"post_{index}_"))

    def test_global526_seam_has_only_tight_physical_supports(self):
        for y in (524,525,526,527,528,539):
            for x in range(0,1800):
                part=recipe.fit_source(None,x,y,self.edges)
                physical=any(recipe.inside(x,y,rect) for rect in recipe.POSTS)
                self.assertEqual(part is not None,physical)

    def test_raw_donors_stay_inside_the_actual_source_canvas(self):
        for y in range(352,540):
            for x in range(64,660):
                part=recipe.fit_source(None,x,y,self.edges)
                if part:
                    sx,sy,kind=part
                    self.assertTrue(0<=sx<1815 and 0<=sy<867,(x,y,part))

    def test_outer_green_reflection_does_not_become_inner_felt_or_wall_rail(self):
        colors=[bytes((80,10,10,255)) for _ in range(660)]
        for first,last,color in ((151,155,(5,30,15,255)),(155,163,(180,140,40,255)),
                                  (163,601,(10,100,50,255)),(601,610,(180,140,40,255)),
                                  (610,615,(5,30,15,255))):
            colors[first:last]=[bytes(color)]*(last-first)
        image=recipe.PNGImage(660,1,b"".join(colors))
        self.assertEqual(recipe.trace_material_row(image,0),(151,163,601,615))
        # The rejected min-green-minus8 rule would take redwood wall143..150.
        self.assertFalse(recipe.table_material(recipe.pixel(image,143,0)))
        self.assertTrue(all(recipe.green_material(recipe.pixel(image,x,0)) for x in range(163,601)))

    def test_far_and_near_rim_use_traced_source_intervals_not_old_rectangles(self):
        for y in tuple(range(352,358))+tuple(range(476,488)):
            for x in range(124 if y<358 else 64,660):
                sx,sy,kind=recipe.fit_source(None,x,y,self.edges)
                self.assertTrue(150<=sx<600)
                self.assertTrue(363<=sy<374 if kind=="far_rim" else 438<=sy<460)

    def test_apron_source_insets_avoid_old_box_corner_material(self):
        self.assertEqual(recipe.apron_source_bounds(464),(123,630))
        self.assertEqual(recipe.apron_source_bounds(489),(129,626))
        for y in range(488,516):
            for x in (72,73,200,620,659):
                sx,sy,kind=recipe.fit_source(None,x,y,self.edges)
                left,right=recipe.apron_source_bounds(sy)
                self.assertTrue(left<=sx<right)
                self.assertEqual(kind,"quiet_apron")


if __name__ == "__main__":
    unittest.main()
