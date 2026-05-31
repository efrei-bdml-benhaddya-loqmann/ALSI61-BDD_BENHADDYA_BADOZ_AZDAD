-- ====================================================
-- script_creation.sql
-- Projet BDD ALSI61 — Outil de gestion de planning
-- ====================================================
-- Exécution : mysql -u root -p < script_creation.sql
-- Testé sur MySQL 8.x
-- ====================================================

-- ----------------------------------------
-- 0. Initialisation
-- ----------------------------------------
DROP DATABASE IF EXISTS planning_entreprise;
CREATE DATABASE planning_entreprise
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE planning_entreprise;

SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------
-- 1. SERVICE
-- ----------------------------------------
CREATE TABLE Service (
    id_service   INT          NOT NULL AUTO_INCREMENT,
    code_service VARCHAR(3)   NOT NULL,
    libelle      VARCHAR(100) NOT NULL,

    CONSTRAINT pk_service       PRIMARY KEY (id_service),
    CONSTRAINT uq_code_service  UNIQUE      (code_service),
    CONSTRAINT ck_code_service  CHECK       (code_service REGEXP '^S[0-9]{2}$')
) ENGINE=InnoDB;

-- ----------------------------------------
-- 2. EMPLOYE
-- ----------------------------------------
CREATE TABLE Employe (
    id_employe    INT          NOT NULL AUTO_INCREMENT,
    nom           VARCHAR(100) NOT NULL,
    prenom        VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL,
    date_embauche DATE         NOT NULL,
    id_service    INT          NOT NULL,
    id_manager    INT              NULL COMMENT 'NULL = sommet hiérarchie (DG)',

    CONSTRAINT pk_employe       PRIMARY KEY (id_employe),
    CONSTRAINT uq_email         UNIQUE      (email),
    CONSTRAINT fk_emp_service   FOREIGN KEY (id_service) REFERENCES Service(id_service)
                                    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_emp_manager   FOREIGN KEY (id_manager) REFERENCES Employe(id_employe)
                                    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------
-- 3. STATUTJOUR
-- ----------------------------------------
CREATE TABLE StatutJour (
    id_statut      INT         NOT NULL AUTO_INCREMENT,
    libelle        VARCHAR(50) NOT NULL,
    code           CHAR(3)     NOT NULL,
    decompte_solde BOOLEAN     NOT NULL DEFAULT FALSE
        COMMENT 'TRUE = décompte sur SoldeConge (CP, RTT)',

    CONSTRAINT pk_statut    PRIMARY KEY (id_statut),
    CONSTRAINT uq_code      UNIQUE      (code),
    CONSTRAINT ck_code      CHECK       (code IN ('CP', 'RTT', 'TT', 'BUR', 'MAL', 'FOR'))
) ENGINE=InnoDB;

-- ----------------------------------------
-- 4. ENTREEPLANNING
-- ----------------------------------------
CREATE TABLE EntreePlanning (
    id_entree  INT  NOT NULL AUTO_INCREMENT,
    date       DATE NOT NULL,
    demi_journee ENUM('matin', 'apres-midi', 'journee') NOT NULL,
    id_employe INT  NOT NULL,
    id_statut  INT  NOT NULL,

    CONSTRAINT pk_entree        PRIMARY KEY (id_entree),
    CONSTRAINT uq_entree        UNIQUE      (id_employe, date, demi_journee),
    CONSTRAINT fk_entree_emp    FOREIGN KEY (id_employe) REFERENCES Employe(id_employe)
                                    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_entree_statut FOREIGN KEY (id_statut)  REFERENCES StatutJour(id_statut)
                                    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------
-- TRIGGER : conflit journee ↔ demi-journée
-- Empêche d'insérer 'journee' si 'matin' ou 'apres-midi' existe déjà
-- et vice-versa, pour le même (id_employe, date)
-- ----------------------------------------
DELIMITER //

CREATE TRIGGER trg_entree_no_overlap_insert
BEFORE INSERT ON EntreePlanning
FOR EACH ROW
BEGIN
    -- Insertion d'une journée complète : vérifier qu'aucune demi-journée n'existe
    IF NEW.demi_journee = 'journee' THEN
        IF EXISTS (
            SELECT 1 FROM EntreePlanning
            WHERE id_employe  = NEW.id_employe
              AND date        = NEW.date
              AND demi_journee IN ('matin', 'apres-midi')
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Conflit : une demi-journée existe déjà pour cet employé à cette date.';
        END IF;

    -- Insertion d'une demi-journée : vérifier qu'aucune journée complète n'existe
    ELSEIF NEW.demi_journee IN ('matin', 'apres-midi') THEN
        IF EXISTS (
            SELECT 1 FROM EntreePlanning
            WHERE id_employe  = NEW.id_employe
              AND date        = NEW.date
              AND demi_journee = 'journee'
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Conflit : une entrée journée complète existe déjà pour cet employé à cette date.';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_entree_no_overlap_update
BEFORE UPDATE ON EntreePlanning
FOR EACH ROW
BEGIN
    IF NEW.demi_journee = 'journee' THEN
        IF EXISTS (
            SELECT 1 FROM EntreePlanning
            WHERE id_employe  = NEW.id_employe
              AND date        = NEW.date
              AND demi_journee IN ('matin', 'apres-midi')
              AND id_entree  != NEW.id_entree
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Conflit (UPDATE) : une demi-journée existe déjà pour cet employé à cette date.';
        END IF;

    ELSEIF NEW.demi_journee IN ('matin', 'apres-midi') THEN
        IF EXISTS (
            SELECT 1 FROM EntreePlanning
            WHERE id_employe  = NEW.id_employe
              AND date        = NEW.date
              AND demi_journee = 'journee'
              AND id_entree  != NEW.id_entree
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Conflit (UPDATE) : une entrée journée complète existe déjà pour cet employé à cette date.';
        END IF;
    END IF;
END //

DELIMITER ;

-- ----------------------------------------
-- 5. DEMANDECONGE
-- ----------------------------------------
CREATE TABLE DemandeConge (
    id_demande          INT      NOT NULL AUTO_INCREMENT,
    date_debut          DATE     NOT NULL,
    date_fin            DATE     NOT NULL,
    demi_journee_debut  ENUM('matin', 'apres-midi', 'journee') NOT NULL DEFAULT 'journee',
    demi_journee_fin    ENUM('matin', 'apres-midi', 'journee') NOT NULL DEFAULT 'journee',
    statut_demande      ENUM('en_attente', 'validee', 'refusee') NOT NULL DEFAULT 'en_attente',
    date_soumission     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motif               TEXT         NULL,
    id_employe          INT      NOT NULL,
    id_statut           INT      NOT NULL COMMENT 'Type de congé : CP, RTT, MAL…',
    id_manager_valideur INT          NULL COMMENT 'NULL si pas encore traité',

    CONSTRAINT pk_demande           PRIMARY KEY (id_demande),
    CONSTRAINT ck_dates_demande     CHECK       (date_debut <= date_fin),
    CONSTRAINT fk_demande_emp       FOREIGN KEY (id_employe)          REFERENCES Employe(id_employe)
                                        ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_demande_statut    FOREIGN KEY (id_statut)           REFERENCES StatutJour(id_statut)
                                        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_demande_manager   FOREIGN KEY (id_manager_valideur) REFERENCES Employe(id_employe)
                                        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------
-- 6. SOLDECONGE
-- ----------------------------------------
CREATE TABLE SoldeConge (
    id_solde      INT            NOT NULL AUTO_INCREMENT,
    annee         YEAR           NOT NULL,
    jours_acquis  DECIMAL(5, 1)  NOT NULL DEFAULT 0,
    jours_pris    DECIMAL(5, 1)  NOT NULL DEFAULT 0,
    id_employe    INT            NOT NULL,
    id_statut     INT            NOT NULL COMMENT 'CP ou RTT uniquement',

    CONSTRAINT pk_solde             PRIMARY KEY (id_solde),
    CONSTRAINT uq_solde             UNIQUE      (id_employe, id_statut, annee),
    CONSTRAINT ck_jours_acquis      CHECK       (jours_acquis >= 0),
    CONSTRAINT ck_jours_pris        CHECK       (jours_pris   >= 0),
    CONSTRAINT ck_solde_positif     CHECK       (jours_acquis - jours_pris >= 0),
    CONSTRAINT fk_solde_emp         FOREIGN KEY (id_employe) REFERENCES Employe(id_employe)
                                        ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_solde_statut      FOREIGN KEY (id_statut)  REFERENCES StatutJour(id_statut)
                                        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ====================================================
-- TRIGGERS
-- ====================================================

DELIMITER //

-- Décompte du solde à la validation d'une demande
CREATE TRIGGER trg_valider_demande
AFTER UPDATE ON DemandeConge
FOR EACH ROW
BEGIN
    DECLARE v_decompte BOOLEAN;
    DECLARE v_nb_jours DECIMAL(5,1);

    IF NEW.statut_demande = 'validee' AND OLD.statut_demande != 'validee' THEN
        SELECT decompte_solde INTO v_decompte
        FROM StatutJour WHERE id_statut = NEW.id_statut;

        IF v_decompte THEN
            IF NEW.demi_journee_debut IN ('matin', 'apres-midi') THEN
                SET v_nb_jours = 0.5;
            ELSE
                SET v_nb_jours = DATEDIFF(NEW.date_fin, NEW.date_debut) + 1;
            END IF;

            UPDATE SoldeConge
            SET    jours_pris = jours_pris + v_nb_jours
            WHERE  id_employe = NEW.id_employe
              AND  id_statut  = NEW.id_statut
              AND  annee      = YEAR(NEW.date_debut);
        END IF;
    END IF;
END//

-- Remboursement du solde à la suppression d'une demande validée
CREATE TRIGGER trg_annuler_conge_valide
AFTER DELETE ON DemandeConge
FOR EACH ROW
BEGIN
    DECLARE v_decompte BOOLEAN;
    DECLARE v_nb_jours DECIMAL(5,1);

    IF OLD.statut_demande = 'validee' THEN
        SELECT decompte_solde INTO v_decompte
        FROM StatutJour WHERE id_statut = OLD.id_statut;

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

-- ====================================================
-- DML — JEU DE DONNÉES
-- ====================================================

-- ----------------------------------------
-- SERVICE
-- ----------------------------------------
INSERT INTO Service (code_service, libelle) VALUES
    ('S01', 'Direction'),
    ('S02', 'Informatique'),
    ('S03', 'Ressources Humaines'),
    ('S04', 'Commercial');

-- ----------------------------------------
-- STATUTJOUR  (ids : CP=1, RTT=2, TT=3, BUR=4, MAL=5, FOR=6)
-- ----------------------------------------
INSERT INTO StatutJour (libelle, code, decompte_solde) VALUES
    ('Congé payé',  'CP',  TRUE),
    ('RTT',         'RTT', TRUE),
    ('Télétravail', 'TT',  FALSE),
    ('Bureau',      'BUR', FALSE),
    ('Maladie',     'MAL', FALSE),
    ('Formation',   'FOR', FALSE);

-- ----------------------------------------
-- EMPLOYE  (managers insérés avant leurs subordonnés)
-- ----------------------------------------
INSERT INTO Employe (nom, prenom, email, date_embauche, id_service, id_manager) VALUES
    ('Benhaddya', 'Loqmann', 'loqmann.benhaddya@entreprise.fr', '2015-03-01', 1, NULL);
INSERT INTO Employe (nom, prenom, email, date_embauche, id_service, id_manager) VALUES
    ('Azdad',            'Samy',   'samy.azdad@entreprise.fr',             '2017-09-15', 2, 1),
    ('Djaleu Tchouamou', 'Ingrid', 'ingrid.djaleu.tchouamou@entreprise.fr','2018-01-10', 3, 1),
    ('Badoz',            'Marius', 'marius.badoz@entreprise.fr',           '2016-06-20', 4, 1);
INSERT INTO Employe (nom, prenom, email, date_embauche, id_service, id_manager) VALUES
    ('Derra',    'Abdel Founeke', 'abdel.derra@entreprise.fr',     '2020-02-03', 2, 2),
    ('Chemli',   'Hechmi',        'hechmi.chemli@entreprise.fr',   '2021-11-08', 2, 2),
    ('Ba',       'Djeneba',       'djeneba.ba@entreprise.fr',      '2019-05-22', 3, 3),
    ('Brignone', 'Anissa',        'anissa.brignone@entreprise.fr', '2022-03-14', 4, 4),
    ('Bichart',  'Adrien',        'adrien.bichart@entreprise.fr',  '2023-09-01', 4, 4),
    ('Grondin',  'David',         'david.grondin@entreprise.fr',   '2021-01-18', 2, 2);

-- ----------------------------------------
-- ENTREEPLANNING — semaine du 25/05/2026 (lun) au 29/05/2026 (ven)
-- ----------------------------------------
INSERT INTO EntreePlanning (date, demi_journee, id_employe, id_statut) VALUES
    ('2026-05-25', 'journee', 1, 4), ('2026-05-26', 'journee', 1, 4),
    ('2026-05-27', 'journee', 1, 3), ('2026-05-28', 'journee', 1, 4),
    ('2026-05-29', 'journee', 1, 3),
    ('2026-05-25', 'journee', 2, 4), ('2026-05-26', 'journee', 2, 3),
    ('2026-05-27', 'journee', 2, 4), ('2026-05-28', 'journee', 2, 4),
    ('2026-05-29', 'journee', 2, 3),
    ('2026-05-25', 'journee', 3, 4), ('2026-05-26', 'journee', 3, 4),
    ('2026-05-27', 'journee', 3, 4), ('2026-05-28', 'journee', 3, 3),
    ('2026-05-29', 'journee', 3, 1),
    ('2026-05-25', 'journee', 4, 3), ('2026-05-26', 'journee', 4, 4),
    ('2026-05-27', 'journee', 4, 4), ('2026-05-28', 'journee', 4, 6),
    ('2026-05-29', 'journee', 4, 6),
    ('2026-05-25', 'journee', 5, 4), ('2026-05-26', 'journee', 5, 4),
    ('2026-05-27', 'journee', 5, 3), ('2026-05-28', 'journee', 5, 3),
    ('2026-05-29', 'matin', 5, 4), ('2026-05-29', 'apres-midi', 5, 3),
    ('2026-05-25', 'journee', 6, 5), ('2026-05-26', 'journee', 6, 5),
    ('2026-05-27', 'journee', 6, 4), ('2026-05-28', 'journee', 6, 4),
    ('2026-05-29', 'journee', 6, 4),
    ('2026-05-25', 'journee', 7, 4), ('2026-05-26', 'journee', 7, 2),
    ('2026-05-27', 'journee', 7, 4), ('2026-05-28', 'journee', 7, 4),
    ('2026-05-29', 'journee', 7, 3),
    ('2026-05-25', 'journee', 8, 4), ('2026-05-26', 'journee', 8, 4),
    ('2026-05-27', 'journee', 8, 4), ('2026-05-28', 'journee', 8, 4),
    ('2026-05-29', 'journee', 8, 1),
    ('2026-05-25', 'journee', 9, 1), ('2026-05-26', 'journee', 9, 1),
    ('2026-05-27', 'journee', 9, 4), ('2026-05-28', 'journee', 9, 4),
    ('2026-05-29', 'journee', 9, 4),
    ('2026-05-25', 'journee', 10, 4), ('2026-05-26', 'journee', 10, 3),
    ('2026-05-27', 'journee', 10, 4), ('2026-05-28', 'journee', 10, 4),
    ('2026-05-29', 'journee', 10, 6);

-- ----------------------------------------
-- DEMANDECONGE  (mix de statuts ; valideur = manager)
-- ----------------------------------------
INSERT INTO DemandeConge
    (date_debut, date_fin, statut_demande, motif, id_employe, id_statut, id_manager_valideur) VALUES
    ('2026-05-25', '2026-05-26', 'validee',    'Week-end prolongé',          9,  1, 4),
    ('2026-05-29', '2026-05-29', 'validee',    'Rendez-vous personnel',      8,  1, 4),
    ('2026-05-29', '2026-05-29', 'validee',    'Pont',                       3,  1, 1),
    ('2026-05-26', '2026-05-26', 'validee',    'Récupération RTT',           7,  2, 3),
    ('2026-06-10', '2026-06-14', 'en_attente', 'Vacances été',               5,  1, NULL),
    ('2026-05-25', '2026-05-26', 'validee',    'Arrêt maladie',              6,  5, 2),
    ('2026-06-02', '2026-06-02', 'en_attente', 'RTT',                        10, 2, NULL),
    ('2026-07-01', '2026-07-15', 'en_attente', 'Congés annuels',             2,  1, NULL),
    ('2026-06-20', '2026-06-20', 'refusee',    'Sous-effectif ce jour',      8,  2, 4),
    ('2026-08-01', '2026-08-10', 'en_attente', 'Vacances août',              9,  1, NULL),
    ('2026-06-05', '2026-06-05', 'refusee',    'Période de clôture',         4,  1, 1),
    ('2026-05-30', '2026-05-30', 'en_attente', 'RTT samedi récupéré',        5,  2, NULL);

-- ----------------------------------------
-- SOLDECONGE  (année 2026 ; CP et RTT par employé)
-- ----------------------------------------
INSERT INTO SoldeConge (annee, jours_acquis, jours_pris, id_employe, id_statut) VALUES
    (2026, 25, 5,  1, 1), (2026, 12, 2,  1, 2),
    (2026, 25, 10, 2, 1), (2026, 12, 3,  2, 2),
    (2026, 25, 12, 3, 1), (2026, 12, 4,  3, 2),
    (2026, 25, 8,  4, 1), (2026, 12, 1,  4, 2),
    (2026, 25, 15, 5, 1), (2026, 12, 6,  5, 2),
    (2026, 25, 3,  6, 1), (2026, 12, 0,  6, 2),
    (2026, 25, 20, 7, 1), (2026, 12, 8,  7, 2),
    (2026, 25, 22, 8, 1), (2026, 12, 10, 8, 2),
    (2026, 25, 25, 9, 1), (2026, 12, 12, 9, 2),
    (2026, 25, 6, 10, 1), (2026, 12, 2, 10, 2);

-- ====================================================
-- VUES
-- ====================================================

-- ----------------------------------------
-- v_demandes_completes — consolide une demande de congé avec son demandeur,
-- son service, son type, son valideur et le nombre de jours décomptés.
-- Factorise les jointures réutilisées par les requêtes et l'application Flask.
-- ----------------------------------------
CREATE OR REPLACE VIEW v_demandes_completes AS
SELECT  dc.id_demande,
        dc.date_debut,
        dc.date_fin,
        dc.demi_journee_debut,
        dc.statut_demande,
        dc.date_soumission,
        dc.motif,
        CONCAT_WS(' ', e.prenom, e.nom)  AS demandeur,
        s.libelle                        AS service,
        sj.code                          AS code_type,
        sj.libelle                       AS type_conge,
        CONCAT_WS(' ', v.prenom, v.nom)  AS valideur,
        CASE
            WHEN dc.demi_journee_debut IN ('matin', 'apres-midi') THEN 0.5
            ELSE DATEDIFF(dc.date_fin, dc.date_debut) + 1
        END                              AS nb_jours
FROM    DemandeConge dc
JOIN    Employe e     ON e.id_employe = dc.id_employe
JOIN    Service s     ON s.id_service = e.id_service
JOIN    StatutJour sj ON sj.id_statut = dc.id_statut
LEFT JOIN Employe v   ON v.id_employe = dc.id_manager_valideur;

-- ----------------------------------------
-- Vérification : afficher les tables créées
-- ----------------------------------------
SHOW TABLES;
