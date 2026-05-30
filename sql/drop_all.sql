-- ====================================================
-- drop_all.sql — Suppression complète de la base
-- ====================================================
USE planning_entreprise;

SET FOREIGN_KEY_CHECKS = 0;

DROP TRIGGER IF EXISTS trg_annuler_conge_valide;
DROP TRIGGER IF EXISTS trg_valider_demande;

DROP TABLE IF EXISTS SoldeConge;
DROP TABLE IF EXISTS DemandeConge;
DROP TABLE IF EXISTS EntreePlanning;
DROP TABLE IF EXISTS StatutJour;
DROP TABLE IF EXISTS Employe;
DROP TABLE IF EXISTS Service;

SET FOREIGN_KEY_CHECKS = 1;

DROP DATABASE IF EXISTS planning_entreprise;
