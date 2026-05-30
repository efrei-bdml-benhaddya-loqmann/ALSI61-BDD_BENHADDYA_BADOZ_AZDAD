-- ====================================================
-- 08_triggers.sql — Triggers sur DemandeConge
-- ====================================================
-- Objectif : garantir la cohérence de SoldeConge quelle que soit
-- la voie d'accès à la base (Flask, Workbench, script direct…).
--
-- trg_valider_demande      : à la validation d'une demande, incrémente
--                            jours_pris si le type décompte du solde.
-- trg_annuler_conge_valide : à la suppression d'une demande déjà validée,
--                            décrémente jours_pris pour rembourser les jours.
-- ====================================================
USE planning_entreprise;

DELIMITER //

-- ----------------------------------------------------
-- Trigger 1 — Décompte du solde à la validation
-- ----------------------------------------------------
CREATE TRIGGER trg_valider_demande
AFTER UPDATE ON DemandeConge
FOR EACH ROW
BEGIN
    DECLARE v_decompte BOOLEAN;
    DECLARE v_nb_jours DECIMAL(5,1);

    -- Ne s'active que lors du passage à 'validee'
    IF NEW.statut_demande = 'validee' AND OLD.statut_demande != 'validee' THEN

        SELECT decompte_solde INTO v_decompte
        FROM StatutJour
        WHERE id_statut = NEW.id_statut;

        IF v_decompte THEN
            -- Demi-journée = 0.5 j ; journée(s) complète(s) = différence + 1
            IF NEW.demi_journee_debut IN ('matin', 'apres-midi') THEN
                SET v_nb_jours = 0.5;
            ELSE
                SET v_nb_jours = DATEDIFF(NEW.date_fin, NEW.date_debut) + 1;
            END IF;

            -- La contrainte CHECK ck_solde_positif rejette automatiquement
            -- un dépassement de solde (jours_acquis - jours_pris >= 0).
            UPDATE SoldeConge
            SET    jours_pris = jours_pris + v_nb_jours
            WHERE  id_employe = NEW.id_employe
              AND  id_statut  = NEW.id_statut
              AND  annee      = YEAR(NEW.date_debut);
        END IF;

    END IF;
END//

-- ----------------------------------------------------
-- Trigger 2 — Remboursement du solde à l'annulation
-- ----------------------------------------------------
CREATE TRIGGER trg_annuler_conge_valide
AFTER DELETE ON DemandeConge
FOR EACH ROW
BEGIN
    DECLARE v_decompte BOOLEAN;
    DECLARE v_nb_jours DECIMAL(5,1);

    -- Ne s'active que si la demande supprimée était déjà validée
    IF OLD.statut_demande = 'validee' THEN

        SELECT decompte_solde INTO v_decompte
        FROM StatutJour
        WHERE id_statut = OLD.id_statut;

        IF v_decompte THEN
            IF OLD.demi_journee_debut IN ('matin', 'apres-midi') THEN
                SET v_nb_jours = 0.5;
            ELSE
                SET v_nb_jours = DATEDIFF(OLD.date_fin, OLD.date_debut) + 1;
            END IF;

            UPDATE SoldeConge
            SET    jours_pris = jours_pris - v_nb_jours
            WHERE  id_employe = OLD.id_employe
              AND  id_statut  = OLD.id_statut
              AND  annee      = YEAR(OLD.date_debut);
        END IF;

    END IF;
END//

DELIMITER ;
