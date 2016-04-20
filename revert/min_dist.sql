-- Revert min_detector_distance:min_dist from pg

BEGIN;

DROP TABLE tempseg.min_detector__distance;

COMMIT;
