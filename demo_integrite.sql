-- =====================================================================
-- demo_integrite.sql — Démos à exécuter PENDANT LA VIDÉO (Partie 2)
-- Domaine : Gestion des congés & plannings  |  BDD : planning_entreprise
--
-- MODE D'EMPLOI : exécuter les blocs UN PAR UN (Ctrl+Entrée sur Workbench).
--   * Les blocs "ECHEC ATTENDU" DOIVENT renvoyer une erreur (c'est le but).
--   * Les blocs "COMPORTEMENT FK" montrent l'effet des ON DELETE.
-- IMPORTANT : ré-exécuter script_creation.sql juste avant la vidéo pour
--             partir d'une base propre (surtout après les blocs B et C).
-- =====================================================================

USE planning_entreprise;


-- =====================================================================
-- 2a. MONTRER LE CONTENU DE QUELQUES TABLES
-- =====================================================================
SELECT * FROM Service;
SELECT * FROM Employe LIMIT 10;
SELECT * FROM DemandeConge LIMIT 10;
SELECT * FROM SoldeConge LIMIT 10;


-- =====================================================================
-- 2b. INTEGRITE — chaque requête ci-dessous DOIT ECHOUER
-- =====================================================================

-- (1) ECHEC ATTENDU : email en double (contrainte UNIQUE uq_email)
--     Email DEJA présent (employé 1, Loqmann Benhaddya).
INSERT INTO Employe (nom, prenom, email, date_embauche, id_service, id_manager)
VALUES ('Test', 'Doublon', 'loqmann.benhaddya@entreprise.fr', '2024-01-01', 1, NULL);
-- Attendu : Error 1062 - Duplicate entry ... for key 'uq_email'

-- (2) ECHEC ATTENDU : code service mal formé (CHECK ck_code_service : doit être S + 2 chiffres)
INSERT INTO Service (code_service, libelle)
VALUES ('XYZ', 'Service invalide');
-- Attendu : Error 3819 - Check constraint 'ck_code_service' is violated

-- (3) ECHEC ATTENDU : date_fin < date_debut (CHECK ck_dates_demande)
INSERT INTO DemandeConge (date_debut, date_fin, id_employe, id_statut)
VALUES ('2026-07-10', '2026-07-05', 1, 1);
-- Attendu : Error 3819 - Check constraint 'ck_dates_demande' is violated

-- (4) ECHEC ATTENDU : deux entrées de planning sur la même demi-journée (UNIQUE uq_entree)
--     date 2026-06-01 libre (les données s'arrêtent au 29/05), statut 1 = CP : 1er INSERT passe, 2e échoue.
INSERT INTO EntreePlanning (date, demi_journee, id_employe, id_statut)
VALUES ('2026-06-01', 'matin', 1, 1);
INSERT INTO EntreePlanning (date, demi_journee, id_employe, id_statut)
VALUES ('2026-06-01', 'matin', 1, 1);
-- Attendu : Error 1062 - Duplicate entry for key 'uq_entree'

-- (5) ECHEC ATTENDU : solde négatif interdit (CHECK ck_solde_positif)
--     jours_pris (12) > jours_acquis (5)  =>  acquis - pris < 0
INSERT INTO SoldeConge (annee, jours_acquis, jours_pris, id_employe, id_statut)
VALUES (2027, 5, 12, 1, 1);
-- Attendu : Error 3819 - Check constraint 'ck_solde_positif' is violated


-- =====================================================================
-- 2c. COMPORTEMENT DES CLES ETRANGERES (ON DELETE)
-- =====================================================================

-- (A) ON DELETE RESTRICT : impossible de supprimer un service qui a des employés
--     ECHEC ATTENDU :
DELETE FROM Service WHERE id_service = 1;
-- Attendu : Error 1451 - Cannot delete or update a parent row (RESTRICT)

-- (B) ON DELETE CASCADE : supprimer un employé efface ses demandes/soldes/planning
--     >>> Choisir un id_employe qui a des demandes (ex : 9, utilisé dans requetes.sql R4).
SELECT 'AVANT' AS etat, COUNT(*) AS nb_demandes FROM DemandeConge WHERE id_employe = 9;
DELETE FROM Employe WHERE id_employe = 9;
SELECT 'APRES' AS etat, COUNT(*) AS nb_demandes FROM DemandeConge WHERE id_employe = 9;
-- Attendu : APRES = 0 (les demandes ont été supprimées en cascade)

-- (C) ON DELETE SET NULL : supprimer un manager détache ses subordonnés (sans les supprimer)
--     >>> Choisir un id_employe qui est manager d'autres (regarder id_manager dans Employe).
SELECT id_employe, nom, id_manager FROM Employe WHERE id_manager = 1;   -- avant
DELETE FROM Employe WHERE id_employe = 1;
SELECT id_employe, nom, id_manager FROM Employe WHERE id_manager IS NULL; -- après : id_manager = NULL
-- Attendu : les subordonnés existent toujours, mais leur id_manager est passé à NULL

-- >>> APRES les blocs B et C (destructeurs), relancer script_creation.sql
--     pour remettre la base propre avant toute autre démo.


-- =====================================================================
-- 2d. (BONUS) MONTRER UN TRIGGER EN ACTION : décompte automatique du solde
-- =====================================================================
-- Demande id 8 = employé 2 (Samy Azdad), CP (id_statut 1), statut 'en_attente',
-- du 2026-07-01 au 2026-07-15 (15 jours). Solde CP 2026 emp 2 : acquis 25, pris 10.
-- La validation déclenche trg_valider_demande : jours_pris passe de 10 à 25.

-- Avant (jours_pris = 10) :
SELECT * FROM SoldeConge WHERE id_employe = 2 AND id_statut = 1 AND annee = 2026;
UPDATE DemandeConge SET statut_demande = 'validee', id_manager_valideur = 1
  WHERE id_demande = 8;
-- Après (jours_pris = 25) :
SELECT * FROM SoldeConge WHERE id_employe = 2 AND id_statut = 1 AND annee = 2026;
