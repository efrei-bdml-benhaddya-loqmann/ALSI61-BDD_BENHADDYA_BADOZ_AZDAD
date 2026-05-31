-- ====================================================
-- requetes.sql
-- Projet BDD ALSI61 — Application de réservation de congés
-- ====================================================
-- 15 requêtes (R1 → R15), centrées sur le domaine « congés ».
-- R1-R10  : jointures, agrégats, regroupements, tri, intervalles de dates.
-- R11-R15 : sous-requêtes (scalaire, dérivée, corrélée) + EXISTS / NOT EXISTS.
-- Chaque requête retourne au moins une ligne sur le jeu de données fourni.
-- ====================================================
USE planning_entreprise;


-- ----------------------------------------------------
-- R1. Toutes les demandes de congé avec demandeur, type et statut.
--     Approche : jointures DemandeConge-Employe-StatutJour.
-- ----------------------------------------------------
SELECT  dc.id_demande,
        CONCAT_WS(' ', e.prenom, e.nom) AS demandeur,
        sj.libelle                      AS type_conge,
        dc.date_debut,
        dc.date_fin,
        dc.statut_demande
FROM    DemandeConge dc
JOIN    Employe e     ON e.id_employe = dc.id_employe
JOIN    StatutJour sj ON sj.id_statut = dc.id_statut
ORDER BY dc.date_soumission DESC;


-- ----------------------------------------------------
-- R2. Nombre de demandes de congé par service.
--     Approche : jointures + regroupement + COUNT.
-- ----------------------------------------------------
SELECT  s.libelle                  AS service,
        COUNT(dc.id_demande)       AS nb_demandes
FROM    Service s
JOIN    Employe e      ON e.id_service = s.id_service
LEFT JOIN DemandeConge dc ON dc.id_employe = e.id_employe
GROUP BY s.id_service, s.libelle
ORDER BY nb_demandes DESC;


-- ----------------------------------------------------
-- R3. Nombre total de jours de congé VALIDÉS par employé.
--     Approche : filtre sur le statut + somme calculée (DATEDIFF) + regroupement.
-- ----------------------------------------------------
SELECT  CONCAT_WS(' ', e.prenom, e.nom)                       AS employe,
        SUM(DATEDIFF(dc.date_fin, dc.date_debut) + 1)         AS nb_jours_valides
FROM    Employe e
JOIN    DemandeConge dc ON dc.id_employe = e.id_employe
WHERE   dc.statut_demande = 'validee'
GROUP BY e.id_employe, e.prenom, e.nom
ORDER BY nb_jours_valides DESC;


-- ----------------------------------------------------
-- R4. Historique des demandes de l'employé id = 9 (Adrien Bichart), triées par date.
--     Approche : jointure + filtre + tri.
-- ----------------------------------------------------
SELECT  dc.date_debut,
        dc.date_fin,
        sj.libelle AS type_conge,
        dc.statut_demande
FROM    DemandeConge dc
JOIN    StatutJour sj ON sj.id_statut = dc.id_statut
WHERE   dc.id_employe = 9
ORDER BY dc.date_debut;


-- ----------------------------------------------------
-- R5. Pour chaque manager valideur : nombre de demandes traitées par statut.
--     Approche : jointure + regroupement multi-colonnes.
-- ----------------------------------------------------
SELECT  CONCAT_WS(' ', v.prenom, v.nom) AS valideur,
        dc.statut_demande,
        COUNT(*)                        AS nb
FROM    DemandeConge dc
JOIN    Employe v ON v.id_employe = dc.id_manager_valideur
GROUP BY dc.id_manager_valideur, v.prenom, v.nom, dc.statut_demande
ORDER BY valideur, dc.statut_demande;


-- ----------------------------------------------------
-- R6. Demandes de congé en attente, avec demandeur et type.
--     Approche : jointures + filtre sur le statut de la demande.
-- ----------------------------------------------------
SELECT  dc.id_demande,
        CONCAT_WS(' ', e.prenom, e.nom) AS demandeur,
        sj.libelle                      AS type_conge,
        dc.date_debut,
        dc.date_fin
FROM    DemandeConge dc
JOIN    Employe e     ON e.id_employe = dc.id_employe
JOIN    StatutJour sj ON sj.id_statut = dc.id_statut
WHERE   dc.statut_demande = 'en_attente'
ORDER BY dc.date_debut;


-- ----------------------------------------------------
-- R7. Pour chaque manager : nombre de demandes de son équipe en attente de validation.
--     Approche : auto-jointure (manager/subordonné) + LEFT JOIN + regroupement.
-- ----------------------------------------------------
SELECT  CONCAT_WS(' ', m.prenom, m.nom) AS manager,
        COUNT(dc.id_demande)            AS nb_a_valider
FROM    Employe m
JOIN    Employe e ON e.id_manager = m.id_employe
LEFT JOIN DemandeConge dc
       ON dc.id_employe = e.id_employe
      AND dc.statut_demande = 'en_attente'
GROUP BY m.id_employe, m.prenom, m.nom
ORDER BY nb_a_valider DESC;


-- ----------------------------------------------------
-- R8. Soldes de congés restants par employé et par type (année 2026).
--     Approche : calcul (acquis - pris) + jointures.
-- ----------------------------------------------------
SELECT  CONCAT_WS(' ', e.prenom, e.nom)      AS employe,
        sj.libelle                           AS type_conge,
        sc.jours_acquis,
        sc.jours_pris,
        (sc.jours_acquis - sc.jours_pris)     AS jours_restants
FROM    SoldeConge sc
JOIN    Employe e     ON e.id_employe = sc.id_employe
JOIN    StatutJour sj ON sj.id_statut = sc.id_statut
WHERE   sc.annee = 2026
ORDER BY employe, type_conge;


-- ----------------------------------------------------
-- R9. Demandes de congé chevauchant la semaine du 25 au 29/05/2026, par type.
--     Approche : filtre par intervalle de dates (chevauchement) + regroupement.
-- ----------------------------------------------------
SELECT  sj.libelle      AS type_conge,
        COUNT(*)        AS nb_demandes
FROM    DemandeConge dc
JOIN    StatutJour sj ON sj.id_statut = dc.id_statut
WHERE   dc.date_debut <= '2026-05-29'
  AND   dc.date_fin   >= '2026-05-25'
GROUP BY sj.id_statut, sj.libelle
ORDER BY nb_demandes DESC;


-- ----------------------------------------------------
-- R10. Demandes refusées : demandeur, type, motif et manager ayant refusé.
--      Approche : jointures + LEFT JOIN auto-référente sur le valideur.
-- ----------------------------------------------------
SELECT  CONCAT_WS(' ', e.prenom, e.nom) AS demandeur,
        sj.libelle                      AS type_conge,
        dc.date_debut,
        dc.motif,
        CONCAT_WS(' ', v.prenom, v.nom) AS refuse_par
FROM    DemandeConge dc
JOIN    Employe e     ON e.id_employe = dc.id_employe
JOIN    StatutJour sj ON sj.id_statut = dc.id_statut
LEFT JOIN Employe v   ON v.id_employe = dc.id_manager_valideur
WHERE   dc.statut_demande = 'refusee'
ORDER BY dc.date_debut;


-- ====================================================
-- R11 → R15 : SOUS-REQUÊTES / EXISTS / NOT EXISTS
-- ====================================================

-- ----------------------------------------------------
-- R11. Employés dont le solde CP restant est supérieur à la MOYENNE
--      des soldes CP restants de l'entreprise.
--      Approche : sous-requête scalaire (AVG) dans le WHERE.
-- ----------------------------------------------------
SELECT  CONCAT_WS(' ', e.prenom, e.nom)          AS employe,
        (sc.jours_acquis - sc.jours_pris)        AS cp_restant
FROM    Employe e
JOIN    SoldeConge sc ON sc.id_employe = e.id_employe
JOIN    StatutJour sj ON sj.id_statut  = sc.id_statut
WHERE   sj.code = 'CP'
  AND   (sc.jours_acquis - sc.jours_pris) > (
            SELECT AVG(sc2.jours_acquis - sc2.jours_pris)
            FROM   SoldeConge sc2
            JOIN   StatutJour sj2 ON sj2.id_statut = sc2.id_statut
            WHERE  sj2.code = 'CP'
        )
ORDER BY cp_restant DESC;


-- ----------------------------------------------------
-- R12. Employés ayant déposé plus de demandes que la MOYENNE
--      de demandes par employé (parmi ceux qui en ont déposé).
--      Approche : sous-requête dérivée (table dérivée) + HAVING.
-- ----------------------------------------------------
SELECT  CONCAT_WS(' ', e.prenom, e.nom) AS employe,
        COUNT(dc.id_demande)            AS nb_demandes
FROM    Employe e
JOIN    DemandeConge dc ON dc.id_employe = e.id_employe
GROUP BY e.id_employe, e.prenom, e.nom
HAVING  COUNT(dc.id_demande) > (
            SELECT AVG(nb) FROM (
                SELECT COUNT(*) AS nb
                FROM   DemandeConge
                GROUP BY id_employe
            ) AS sous_total
        )
ORDER BY nb_demandes DESC;


-- ----------------------------------------------------
-- R13. Employés ayant AU MOINS UNE demande de congé validée.
--      Approche : EXISTS (sous-requête corrélée).
-- ----------------------------------------------------
SELECT  e.nom, e.prenom
FROM    Employe e
WHERE   EXISTS (
            SELECT 1
            FROM   DemandeConge dc
            WHERE  dc.id_employe = e.id_employe
              AND  dc.statut_demande = 'validee'
        )
ORDER BY e.nom;


-- ----------------------------------------------------
-- R14. Employés n'ayant JAMAIS déposé de demande de congé.
--      Approche : NOT EXISTS (sous-requête corrélée).
-- ----------------------------------------------------
SELECT  e.nom, e.prenom
FROM    Employe e
WHERE   NOT EXISTS (
            SELECT 1
            FROM   DemandeConge dc
            WHERE  dc.id_employe = e.id_employe
        )
ORDER BY e.nom;


-- ----------------------------------------------------
-- R15. Employés ayant pris plus de jours de CP que la MOYENNE
--      de CP pris DANS LEUR PROPRE SERVICE.
--      Approche : sous-requête corrélée (corrélation sur le service).
-- ----------------------------------------------------
SELECT  CONCAT_WS(' ', e.prenom, e.nom) AS employe,
        s.libelle                       AS service,
        sc.jours_pris                   AS cp_pris
FROM    Employe e
JOIN    Service s     ON s.id_service = e.id_service
JOIN    SoldeConge sc ON sc.id_employe = e.id_employe
JOIN    StatutJour sj ON sj.id_statut  = sc.id_statut
WHERE   sj.code = 'CP'
  AND   sc.jours_pris > (
            SELECT AVG(sc2.jours_pris)
            FROM   Employe e2
            JOIN   SoldeConge sc2 ON sc2.id_employe = e2.id_employe
            JOIN   StatutJour sj2 ON sj2.id_statut  = sc2.id_statut
            WHERE  sj2.code = 'CP'
              AND  e2.id_service = e.id_service
        )
ORDER BY service, cp_pris DESC;




-- Exemple d'utilisation de la vue : tableau de bord des demandes validées,
-- avec le nombre de jours décomptés, sans réécrire la moindre jointure.
SELECT  demandeur,
        service,
        type_conge,
        nb_jours,
        valideur
FROM    v_demandes_completes
WHERE   statut_demande = 'validee'
ORDER BY nb_jours DESC, demandeur;
