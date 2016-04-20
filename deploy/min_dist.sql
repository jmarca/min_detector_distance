-- Deploy min_detector_distance:min_dist to pg
-- requires: detector_lines:detector_lines
-- requires: numbered_route_lines:nrl
-- requires: tdetector:tdetector
-- requires: canonical_direction:canonical_direction

BEGIN;

-- use a temp table for all distances, then take the minimum of it
CREATE TEMP TABLE detector__distances (
 score    numeric,
 detector_ids text[],
 refnum   numeric,
 freeway_dir text,
 relation_direction  text
)
ON COMMIT DROP;

INSERT INTO detector__distances
SELECT st_hausdorffdistance(nrl.routeline,wl.geom) as score,
       detector_ids,
       nrl.refnum,
       newtbmap.canonical_direction(wl.direction)  as freeway_dir,
       nrl.direction as relation_direction
from tempseg.detector_lines wl
left outer join  tempseg.numbered_route_lines nrl  on (
              wl.refnum=nrl.refnum AND
              (nrl.direction='both'
                 OR newtbmap.canonical_direction( wl.direction )=coalesce(nrl.direction,newtbmap.canonical_direction( wl.direction ))
              )
)
;

WITH minimums as (
    SELECT detector_ids,relation_direction,min(score) as min_score
      FROM detector__distances
      GROUP BY detector_ids,relation_direction
),
need_to_update_to_window_fn as(
    SELECT b.*
    FROM minimums a
    JOIN detector__distances b ON (a.detector_ids=b.detector_ids
                             AND a.relation_direction=b.relation_direction
                             AND a.min_score = b.score )
)
SELECT c.score,refnum,
       unnest(c.detector_ids) as detector_id,
       freeway_dir,relation_direction
INTO tempseg.min_detector__distance
FROM need_to_update_to_window_fn c ;



CREATE INDEX tempseg_min_detector__distance_site_no_index
       ON tempseg.min_detector__distance (detector_id);
CREATE INDEX tempseg_min_detector__distance_relation_id_index
       ON tempseg.min_detector__distance (refnum);

COMMIT;

-- VACUUM ANALYZE tempseg.min_detector__distance;
