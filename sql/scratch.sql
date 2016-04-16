--- cut from '~/repos/jem/osm/sql/views/versioned_routes_work.sql'

drop table if exists  tempseg.detector__distances;

SELECT st_hausdorffdistance(nrl.routeline,wl.geom) as score, detector_ids, nrl.refnum, canonical_direction(wl.direction) as freeway_dir, nrl.direction as relation_direction
INTO tempseg.detector__distances
from tempseg.numbered_route_lines nrl
join  tempseg.detector_lines wl  on (
                         wl.refnum=nrl.refnum and
                         (nrl.direction='both'
                          or canonical_direction( wl.direction )=coalesce(nrl.direction,canonical_direction( wl.direction ))
                         )
                       )
;

DROP TABLE IF EXISTS tempseg.min_detector__distance;

select c.score,refnum,unnest(c.detector_ids) as detector_id, freeway_dir,relation_direction
into tempseg.min_detector__distance
FROM (
  select b.*
  from
    ( select detector_ids,relation_direction,min(score) as min_score from tempseg.detector__distances  group by detector_ids,relation_direction
    ) a
    join tempseg.detector__distances b on (a.detector_ids=b.detector_ids and a.relation_direction=b.relation_direction and a.min_score = b.score )
) c ;


CREATE INDEX tempseg_min_detector__distance_site_no_index ON tempseg.min_detector__distance (detector_id);
CREATE INDEX tempseg_min_detector__distance_relation_id_index ON tempseg.min_detector__distance (refnum);
vacuum analyze tempseg.min_detector__distance;


-- issue, what if there is no line to match the detector "line"

SELECT st_hausdorffdistance(nrl.routeline,wl.geom) as score,
       detector_ids,
       wl.refnum as detectors_refnum,
       nrl.refnum as refnum,
       newtbmap.canonical_direction(wl.direction)  as freeway_dir,
       nrl.direction as relation_direction
from tempseg.detector_lines wl
join  tempseg.numbered_route_lines nrl  on (
              wl.refnum=nrl.refnum AND
              (nrl.direction='both'
                 OR newtbmap.canonical_direction( wl.direction )=coalesce(nrl.direction,newtbmap.canonical_direction( wl.direction ))
              )
)
;
--
-- without left outer join, get 193.
-- with left outer join, get 212,
--
-- osm=# select count(*) from tempseg.detector_lines ;
--  count
-- -------
--    212
-- (1 row)

-- why are some freeways not in OSM?  Is it direction issues?

select a.detector_ids,a.detectors_refnum,b.refnum,a.freeway_dir,b.direction as relation_direction from
(SELECT st_hausdorffdistance(nrl.routeline,wl.geom) as score,
       detector_ids,
       wl.refnum as detectors_refnum,
       nrl.refnum as refnum,
       newtbmap.canonical_direction(wl.direction)  as freeway_dir,
       nrl.direction as relation_direction
from tempseg.detector_lines wl
left outer join  tempseg.numbered_route_lines nrl  on (
              wl.refnum=nrl.refnum AND
              (nrl.direction='both'
                 OR newtbmap.canonical_direction( wl.direction )=coalesce(nrl.direction,newtbmap.canonical_direction( wl.direction ))
              )
)
)a left outer join tempseg.numbered_route_lines b on (a.detectors_refnum=b.refnum)
where a.refnum is null
order by detectors_refnum,freeway_dir
;

--  detectors_refnum | refnum | freeway_dir | relation_direction
-- ------------------+--------+-------------+--------------------
--                15 |     15 | west        | north
--                15 |     15 | west        | south
--                15 |     15 | west        | east
--                26 |     26 | east        | south
--                26 |     26 | west        | south
--                28 |     28 | east        | south
--                28 |     28 | west        | south
--                30 |     30 | east        | south
--                30 |     30 | west        | south
--                51 |        | north       |
--                51 |        | south       |
--                67 |        | north       |
--                67 |        | south       |
--               275 |        | west        |
--               580 |    580 | north       | east
--               580 |    580 | north       | west
--               780 |    780 | east        | south
--               780 |    780 | east        | north
--               780 |    780 | west        | north
--               780 |    780 | west        | south
--               945 |        | east        |
--               945 |        | west        |
--               948 |        | north       |
--               948 |        | south       |
-- (24 rows)
