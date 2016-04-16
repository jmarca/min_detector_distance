-- Deploy min_detector_distance:min_dist to pg
-- requires: detector_lines:detector_lines
-- requires: numbered_route_lines:nrl

BEGIN;

-- use a temp table for all distances, then take the minimum of it
CREATE TEMP TABLE detector__distances (
 score    numeric,
 refnum   numeric,
 freeway_dir text,
 relation_direction  text
)
ON COMMIT DROP;

-- INSERT INTO detector__distances
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


COMMIT;
