-- ====================================================
-- run_all.sql — Exécute tous les scripts dans le bon ordre
-- ====================================================
-- IMPORTANT : les chemins SOURCE sont relatifs au dossier courant.
-- Lancer depuis le dossier sql/ :
--     cd sql
--     mysql -u root -p < run_all.sql
-- Ou dans MySQL Workbench : ouvrir ce fichier après avoir fait
-- "cd" vers le dossier sql/ (sinon ouvrir chaque fichier 00→06 à la main).
-- ====================================================

SOURCE 00_database.sql;
SOURCE 01_service.sql;
SOURCE 02_employe.sql;
SOURCE 03_statutjour.sql;
SOURCE 04_entreeplanning.sql;
SOURCE 05_demandeconge.sql;
SOURCE 06_soldeconge.sql;
SOURCE 08_triggers.sql;
SOURCE 07_data.sql;
SOURCE 09_vues.sql;

SHOW TABLES;
