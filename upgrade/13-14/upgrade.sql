------------------------------------------------------------------------------
-- cr�ation de la table log
--
-- M�thode :
--    - modifier ce fichier pour indiquer les utilisateurs (lignes GRANT)
--    - psql dns < upgrade.sql 
--
-- $Id: upgrade.sql,v 1.1 2007-11-27 16:19:24 pda Exp $
------------------------------------------------------------------------------

CREATE TABLE log (
    date		TIMESTAMP WITHOUT TIME ZONE
				DEFAULT CURRENT_TIMESTAMP
				NOT NULL,
    subsys		TEXT NOT NULL,
    event		TEXT NOT NULL,
    login		TEXT,
    ip			INET,
    msg			TEXT
) ;

GRANT ALL ON log TO dns ;
GRANT ALL ON log TO jean ;
GRANT ALL ON log TO pda ;
