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
