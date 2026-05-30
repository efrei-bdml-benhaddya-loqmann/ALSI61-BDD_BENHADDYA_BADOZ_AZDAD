<!--
====================================================================
  CONSIGNES DE RÉDACTION — À LIRE AVANT DE COMPLÉTER (puis à supprimer)
====================================================================
Ce fichier est le SQUELETTE du rapport. Le début et la fin sont rédigés.
Les TROIS parties techniques sont à compléter par chaque membre :

  • Partie I — MCD & MLD ........... Rédacteur : ____________________
  • Partie II — Base de données SQL  Rédacteur : ____________________
  • Partie III — Application Flask .. Rédacteur : ____________________

Équipe : Loqmann BENHADDYA · Marius BADOZ · Samy AZDAD

Règles de cohérence :
  - On reste en Markdown jusqu'à la fin ; la mise en forme PDF se fera ensuite.
  - Chaque zone « À COMPLÉTER » liste les critères de l'énoncé à couvrir.
  - Ne pas supprimer les rappels de critères tant que la partie n'est pas finie.
  - Supprimer ce bloc de consignes avant l'export PDF.
====================================================================
-->

# Projet de Base de Données — Réservation de congés

### Outil de gestion du planning et des congés d'une entreprise

**Cours :** Bases de Données Avancées — ALSI61
**Niveau :** INGE1-APP-BDML
**SGBD :** MySQL 8.x · **Application :** Python / Flask
**Date de rendu :** 31 mai 2026

**Équipe (trinôme) :**

| Membre | Partie rédigée |
|---|---|
| Loqmann BENHADDYA | _(à compléter)_ |
| Marius BADOZ | _(à compléter)_ |
| Samy AZDAD | _(à compléter)_ |

**Dépôt GitHub :** `ALSI-BDD_BENHADDYA_BADOZ_AZDAD`

---

## Sommaire

1. Présentation du sujet
2. Description du domaine
   - 2.1 Choix du domaine
   - 2.2 Règles métier
   - 2.3 Dictionnaire des données
3. **Partie I — Modélisation (MCD & MLD)** *(à rédiger)*
4. **Partie II — Base de données SQL (DDL, DML, 15 requêtes)** *(à rédiger)*
5. **Partie III — Application Flask** *(à rédiger)*
6. Bilan critique et améliorations
7. Annexes et livrables

---

## 1. Présentation du sujet

Ce projet consiste à concevoir, implémenter puis interroger une base de données relationnelle complète autour d'un domaine métier réel : **la gestion des congés et du planning d'une entreprise**. Le système permet à un employé de réserver, modifier ou annuler une demande de congé, à son manager de la valider ou de la refuser, et au système de tenir à jour automatiquement le planning et le solde de jours de chaque employé.

Le travail est structuré en quatre parties qui s'enchaînent : la modélisation conceptuelle et logique (MCD/MLD), la traduction en base de données MySQL (script DDL, jeu de données DML et quinze requêtes d'interrogation), le développement d'une application Flask connectée à cette base, et enfin une présentation vidéo. Chaque étape s'appuie sur la précédente : le MLD découle du MCD, le script SQL découle du MLD, et l'application s'appuie sur le schéma SQL.

Le domaine retenu compte **six entités distinctes** et inclut une **association ternaire** (l'entrée de planning, qui relie un employé, un jour et un statut), ce qui satisfait les contraintes de richesse exigées par l'énoncé.

---

## 2. Description du domaine

### 2.1 Choix du domaine

Nous avons choisi le domaine de la **gestion des congés et du planning d'entreprise**, un domaine que nous côtoyons dans le cadre de notre alternance et qui est suffisamment riche pour mobiliser tous les concepts du cours.

L'entreprise est découpée en **services** (Informatique, RH, etc.), chacun regroupant plusieurs **employés**. Chaque employé peut avoir un **manager** (lui-même employé), ce qui crée une hiérarchie. Un employé pose des **demandes de congé** sur une plage de dates ; ces demandes sont validées ou refusées par son manager. Le planning quotidien de chaque employé est matérialisé par des **entrées de planning**, qui indiquent, pour un jour (ou une demi-journée) donné, le **statut** de l'employé : congé payé, RTT, télétravail, présence au bureau, maladie ou formation. Enfin, chaque employé dispose d'un **solde de congés** par type et par année, mis à jour à chaque validation.

Le système distingue volontairement deux notions :

- la **demande de congé**, qui est l'archive RH d'une requête posée par un employé ;
- l'**entrée de planning**, qui représente la réalité terrain jour par jour.

Quand une demande est validée, l'application génère les entrées de planning correspondantes et décrémente le solde. Cette séparation reflète le fonctionnement réel d'un outil RH et enrichit le modèle.

**Entités du domaine (6) :** `Service`, `Employe`, `StatutJour`, `EntreePlanning`, `DemandeConge`, `SoldeConge`.

### 2.2 Règles métier

Les règles métier ci-dessous ont servi de base à la conception du MCD. Elles sont garanties soit par des contraintes SQL (PK, UNIQUE, CHECK, FK), soit par des triggers, soit par la logique applicative.

| # | Règle métier | Garantie par |
|---|---|---|
| RM1 | Chaque employé appartient à **exactement un** service. | FK `id_service` NOT NULL |
| RM2 | Un employé a **au plus un** manager direct ; un manager nul désigne le sommet de la hiérarchie (DG). | FK auto-référente `id_manager` (NULL autorisé) |
| RM3 | Le code d'un service est de la forme **« S » suivi de 2 chiffres** (S01, S02…). | CHECK `code_service REGEXP '^S[0-9]{2}$'` |
| RM4 | Chaque statut de jour possède un **code unique** parmi : CP, RTT, TT, BUR, MAL, FOR. | UNIQUE + CHECK sur `code` |
| RM5 | Seuls les statuts CP et RTT **décomptent** du solde de congés. | Attribut `decompte_solde` |
| RM6 | Une entrée de planning est **unique** pour un triplet (employé, date, demi-journée). | UNIQUE `(id_employe, date, demi_journee)` |
| RM7 | Pour un même employé et un même jour, une entrée « journée » ne peut **pas coexister** avec une entrée « matin » ou « après-midi ». | Triggers BEFORE INSERT / BEFORE UPDATE |
| RM8 | Sur toute demande de congé, **`date_debut ≤ date_fin`**. | CHECK |
| RM9 | Une demande a un statut parmi **en_attente / validee / refusee**, initialisé à `en_attente`. | ENUM + DEFAULT |
| RM10 | Le **solde disponible ne peut pas être négatif** : `jours_acquis − jours_pris ≥ 0`. | CHECK |
| RM11 | Il existe **un seul solde** par (employé, type de congé, année). | UNIQUE `(id_employe, id_statut, annee)` |
| RM12 | La **validation** d'une demande génère les entrées de planning et met à jour le solde. | Logique applicative (Flask) |

### 2.3 Dictionnaire des données

> Le dictionnaire complet, table par table, figure dans le fichier `dictionnaire.md` du dépôt. Il est repris intégralement ci-dessous pour le rapport.

#### Table `Service`

| Attribut | Type SQL | Contraintes | Description |
|---|---|---|---|
| `id_service` | INT | PK, AUTO_INCREMENT, NOT NULL | Identifiant unique du service |
| `code_service` | VARCHAR(3) | UNIQUE, NOT NULL, CHECK `S##` | Code court du service (ex : S01) |
| `libelle` | VARCHAR(100) | NOT NULL | Nom complet du service (ex : Informatique, RH) |

#### Table `Employe`

| Attribut | Type SQL | Contraintes | Description |
|---|---|---|---|
| `id_employe` | INT | PK, AUTO_INCREMENT, NOT NULL | Identifiant unique de l'employé |
| `nom` | VARCHAR(100) | NOT NULL | Nom de famille |
| `prenom` | VARCHAR(100) | NOT NULL | Prénom |
| `email` | VARCHAR(150) | UNIQUE, NOT NULL | E-mail professionnel (identifiant de connexion) |
| `date_embauche` | DATE | NOT NULL | Date d'entrée dans l'entreprise |
| `id_service` | INT | FK → Service, NOT NULL | Service de rattachement |
| `id_manager` | INT | FK → Employe (auto-ref), NULL | Manager direct ; NULL = sommet de hiérarchie |

#### Table `StatutJour`

| Attribut | Type SQL | Contraintes | Description |
|---|---|---|---|
| `id_statut` | INT | PK, AUTO_INCREMENT, NOT NULL | Identifiant unique du statut |
| `libelle` | VARCHAR(50) | NOT NULL | Libellé long (ex : Congé Payé) |
| `code` | CHAR(3) | UNIQUE, NOT NULL, CHECK | Code court : CP, RTT, TT, BUR, MAL, FOR |
| `decompte_solde` | BOOLEAN | NOT NULL, DEFAULT FALSE | TRUE si le statut décompte du solde (CP, RTT) |

*Valeurs de référence :* CP (Congé Payé, décompte), RTT (décompte), TT (Télétravail), BUR (Présence Bureau), MAL (Maladie), FOR (Formation).

#### Table `EntreePlanning` — *association ternaire matérialisée*

> Relie **Employé × Jour × StatutJour**. L'attribut `demi_journee` porte la granularité de la ternaire.

| Attribut | Type SQL | Contraintes | Description |
|---|---|---|---|
| `id_entree` | INT | PK, AUTO_INCREMENT, NOT NULL | Identifiant unique de l'entrée |
| `date` | DATE | NOT NULL | Jour concerné |
| `demi_journee` | ENUM | NOT NULL | `matin`, `apres-midi` ou `journee` |
| `id_employe` | INT | FK → Employe, NOT NULL | Employé concerné |
| `id_statut` | INT | FK → StatutJour, NOT NULL | Statut du jour |

*Contraintes :* UNIQUE `(id_employe, date, demi_journee)` ; triggers anti-chevauchement journée/demi-journée.

#### Table `DemandeConge`

| Attribut | Type SQL | Contraintes | Description |
|---|---|---|---|
| `id_demande` | INT | PK, AUTO_INCREMENT, NOT NULL | Identifiant unique de la demande |
| `date_debut` | DATE | NOT NULL | Premier jour demandé |
| `date_fin` | DATE | NOT NULL, CHECK ≥ date_debut | Dernier jour demandé |
| `demi_journee_debut` | ENUM | NOT NULL, DEFAULT `journee` | Précision du premier jour |
| `demi_journee_fin` | ENUM | NOT NULL, DEFAULT `journee` | Précision du dernier jour |
| `statut_demande` | ENUM | NOT NULL, DEFAULT `en_attente` | `en_attente`, `validee`, `refusee` |
| `date_soumission` | DATETIME | NOT NULL, DEFAULT NOW() | Horodatage de la soumission |
| `motif` | TEXT | NULL | Motif optionnel |
| `id_employe` | INT | FK → Employe, NOT NULL | Employé demandeur |
| `id_statut` | INT | FK → StatutJour, NOT NULL | Type de congé demandé |
| `id_manager_valideur` | INT | FK → Employe, NULL | Manager ayant traité ; NULL si non traité |

#### Table `SoldeConge`

| Attribut | Type SQL | Contraintes | Description |
|---|---|---|---|
| `id_solde` | INT | PK, AUTO_INCREMENT, NOT NULL | Identifiant unique du solde |
| `annee` | YEAR | NOT NULL | Année concernée |
| `jours_acquis` | DECIMAL(5,1) | NOT NULL, CHECK ≥ 0, DEFAULT 0 | Jours acquis sur l'année |
| `jours_pris` | DECIMAL(5,1) | NOT NULL, CHECK ≥ 0, DEFAULT 0 | Jours consommés |
| `id_employe` | INT | FK → Employe, NOT NULL | Employé concerné |
| `id_statut` | INT | FK → StatutJour, NOT NULL | Type de congé (CP ou RTT en pratique) |

*Contraintes :* UNIQUE `(id_employe, id_statut, annee)` ; CHECK `jours_acquis − jours_pris ≥ 0`.

---
---

# Partie I — Modélisation de la base de données (MCD & MLD)

> **Rédacteur : _______________________**
> *Reste en Markdown. Insérer le schéma MCD (export draw.io / Looping / Workbench) en image, puis le supprimer/convertir au moment du PDF.*

<!-- ============================================================
  À COMPLÉTER — Critères de l'énoncé à couvrir IMPÉRATIVEMENT :
  [ ] MCD : toutes les entités + leurs attributs
  [ ] MCD : toutes les associations entre entités
  [ ] MCD : cardinalités (min, max) de CHAQUE côté de CHAQUE association
  [ ] MCD : attributs portés par les associations (s'il y en a)
  [ ] Justifier le respect de la 3e Forme Normale (3FN)
  [ ] ≥ 5 entités distinctes (nous en avons 6) ✓
  [ ] ≥ 1 association ternaire OU porteuse d'attributs
      → EntreePlanning = ternaire Employé × Jour × Statut ✓
  [ ] Schéma MCD réalisé avec un outil (draw.io / Looping / Workbench),
      inséré comme image dans le rapport
  [ ] MLD : règles de passage MCD → MLD appliquées
  [ ] MLD : notation textuelle complète NomTable(clé, attr, #FK)
  Fichiers de référence du dépôt : MCD.mermaid, mcd.md, MLD.txt
============================================================ -->

## 4. Modèle Conceptuel de Données (MCD)

### 4.1 Schéma MCD

*[Insérer ici l'image du schéma MCD.]*

### 4.2 Entités et attributs

*[Décrire chaque entité et ses attributs.]*

### 4.3 Associations et cardinalités

*[Lister chaque association avec ses cardinalités (min, max) des deux côtés. Mettre en évidence l'association ternaire `EntreePlanning` et l'auto-association de management.]*

### 4.4 Justification de la 3e Forme Normale (3FN)

*[Démontrer 1FN → 2FN → 3FN : atomicité des attributs, dépendance pleine à la clé, absence de dépendance transitive.]*

## 5. Modèle Logique de Données (MLD)

### 5.1 Règles de passage MCD → MLD

*[Expliquer les règles appliquées : entité → table ; association (1,n)/(1,1)–(0,n) → clé étrangère ; (0,n)–(0,n) → table de relation ; attributs d'association → attributs de la table relation.]*

### 5.2 Notation textuelle du MLD

*[Donner la notation complète sous la forme `NomTable(clé_primaire, attribut, #clé_etrangere)`. Base de départ disponible dans `MLD.txt`.]*

---
---

# Partie II — Base de données SQL

> **Rédacteur : _______________________**
> *SGBD cible : MySQL. Le script doit s'exécuter sans erreur sur une installation standard.*

<!-- ============================================================
  À COMPLÉTER — Critères de l'énoncé à couvrir IMPÉRATIVEMENT :
  [ ] DDL : CREATE DATABASE IF NOT EXISTS + sélection de la base
  [ ] DDL : DROP TABLE IF EXISTS (ré-exécutable)
  [ ] DDL : clés primaires, clés étrangères AVEC ON DELETE / ON UPDATE
  [ ] DDL : contraintes NOT NULL, UNIQUE, CHECK pertinentes
  [ ] DML : INSERT INTO peuplant CHAQUE table, jeu cohérent
  [ ] Les 15 requêtes R1–R15, chacune avec un BREF commentaire d'approche
  [ ] Couvrir : SELECT/WHERE/ORDER BY, INNER/LEFT JOIN, GROUP BY/HAVING,
      sous-requêtes scalaires/corrélées, IN/NOT IN, EXISTS/NOT EXISTS
  Fichiers de référence du dépôt : script_creation.sql, sql/*.sql, requetes.sql
  (Mapping des 15 requêtes au domaine déjà présent dans requetes.sql :
   R1 demandes+demandeur+type+statut ; R2 demandes/service ;
   R3 jours validés/employé ; R4 historique d'un employé ;
   R5 demandes traitées/manager/statut ; R6 demandes en attente ;
   R7 file de validation par manager ; R8 soldes restants 2026 ;
   R9 demandes chevauchant une semaine ; R10 demandes refusées+motif ;
   R11 solde CP > moyenne ; R12 employés > moyenne de demandes ;
   R13 employés avec ≥1 validée ; R14 employés sans demande ;
   R15 employés CP pris > moyenne.)
============================================================ -->

## 6. Script de création (DDL)

### 6.1 Création de la base et des tables

*[Présenter la stratégie : ordre de création respectant les dépendances (Service → Employe → StatutJour → EntreePlanning → DemandeConge → SoldeConge), DROP/CREATE, contraintes. Extraits de code commentés.]*

### 6.2 Contraintes d'intégrité et triggers

*[Détailler PK, FK avec ON DELETE/ON UPDATE, UNIQUE, CHECK, et les triggers anti-chevauchement d'`EntreePlanning`.]*

## 6bis. Jeu de données (DML)

*[Décrire le jeu de données inséré (volume par table, cohérence). Préciser que `SELECT COUNT(*) FROM EntreePlanning;` renvoie 51.]*

## 7. Les 15 requêtes SQL (R1 → R15)

*[Pour chaque requête : énoncé adapté au domaine, code SQL, bref commentaire d'approche, et éventuellement un extrait de résultat.]*

### 7.1 Requêtes de base (R1–R3)
*[…]*

### 7.2 Requêtes avec jointures (R4–R6)
*[…]*

### 7.3 Requêtes avec agrégats (R7–R10)
*[…]*

### 7.4 Requêtes avancées — sous-requêtes, EXISTS/NOT EXISTS (R11–R15)
*[…]*

---
---

# Partie III — Application Flask

> **Rédacteur : _______________________**
> *Langage : Python / Flask. Application web connectée à MySQL.*

<!-- ============================================================
  À COMPLÉTER — Critères de l'énoncé à couvrir IMPÉRATIVEMENT :
  [ ] Architecture de l'application + connexion à MySQL
  [ ] Fonctionnalités du menu :
      [ ] Ajouter un enregistrement
      [ ] Lister tous les enregistrements
      [ ] Rechercher par un critère
      [ ] Modifier un enregistrement
      [ ] Supprimer un enregistrement
      [ ] Afficher un classement / une statistique globale
      [ ] Rechercher un élément par mot-clé
      [ ] Afficher le détail d'un enregistrement + ses données associées
  NB : l'énoncé demandait une interface console ; nous avons fait le choix
       d'une interface WEB (Flask + Jinja2 + Bootstrap), plus riche. À justifier.
  Fichiers de référence du dépôt : src/app.py, src/db.py (connexion),
  src/templates/*.html. Routes existantes : /, /reserver, /conges/<id>,
  /conges/<id>/modifier, /conges/<id>/annuler, /conges/<id>/valider,
  /conges/<id>/refuser, /calendrier, /stats, /utilisateur.
============================================================ -->

## 8. Architecture de l'application

L'application suit une architecture en trois couches :

- **Routage (app.py)** : dix routes [Flask](https://flask.palletsprojects.com/en/stable/quickstart/) couvrent toutes les opérations CRUD sur `DemandeConge`, plus deux vues de consultation (calendrier, statistiques). Chaque route délègue les accès base à `db.py` et renvoie un template [Jinja2](https://jinja.palletsprojects.com/en/stable/templates/).
- **Accès données (db.py)** : deux helpers (`query()` pour les SELECT, `execute()` pour les INSERT/UPDATE/DELETE) encapsulent la connexion MySQL. Les requêtes sont systématiquement paramétrées — aucune concaténation de chaîne SQL — ce qui élimine le risque d'injection SQL.
- **Présentation (templates/)** : templates Jinja2 + Bootstrap 5 partageant un layout commun (`base.html`). La navbar injecte automatiquement l'utilisateur courant via un [`context_processor`](https://flask.palletsprojects.com/en/stable/templating/#context-processors).

**Choix d'une interface web plutôt que console.** Flask permet de produire une interface proche d'un véritable outil RH, de tester le CRUD visuellement, et de démontrer l'intégration SQL/Python dans un contexte réaliste. Les huit opérations demandées par l'énoncé existent toutes sous forme de routes HTTP.

## 9. Connexion à la base de données

`db.py` centralise la connexion à MySQL via [mysql-connector-python](https://dev.mysql.com/doc/connector-python/en/connector-python-example-connecting.html). Les paramètres (hôte, port, base, identifiants) sont lus depuis un fichier `.env` par [python-dotenv](https://pypi.org/project/python-dotenv/), ce qui évite de versionner les credentials.

## 10. Fonctionnalités

L'entité principale du CRUD est `DemandeConge`. Les huit fonctionnalités de l'énoncé sont couvertes :

| # | Fonctionnalité | Route | Opération SQL |
|---|---|---|---|
| 1 | Lister mes demandes + filtre par statut | `GET /` | SELECT + clause WHERE optionnelle |
| 2 | Réserver un congé (ajouter) | `GET/POST /reserver` | INSERT |
| 3 | Voir le détail + données associées | `GET /conges/<id>` | SELECT avec JOINs |
| 4 | Modifier une demande | `GET/POST /conges/<id>/modifier` | UPDATE |
| 5 | Annuler / supprimer | `POST /conges/<id>/annuler` | DELETE |
| 6 | Valider (manager) — décompte solde | `POST /conges/<id>/valider` | UPDATE + UPDATE SoldeConge |
| 7 | Refuser (manager) | `POST /conges/<id>/refuser` | UPDATE |
| 8 | Calendrier équipe + statistiques | `GET /calendrier`, `GET /stats` | SELECT avec agrégats |

**Gestion des demi-journées.** Le schéma `DemandeConge` possède deux colonnes `demi_journee_debut` et `demi_journee_fin` (ENUM `matin` / `apres-midi` / `journee`). Le formulaire expose un sélecteur radio *Journée(s) complète(s)* / *Demi-journée* : en mode journée, les deux colonnes valent `journee` ; en mode demi-journée, `date_debut = date_fin` et les deux colonnes prennent la valeur choisie (`matin` ou `apres-midi`). Le décompte du solde utilise 0,5 jour pour une demi-journée au lieu de 1.

**Corrections de qualité appliquées en cours de développement :**

**Vérification d'appartenance (IDOR).** Les routes `conge_modifier` et `conge_annuler` comparent désormais `demande["id_employe"]` avec `_current_user_id()` et appellent `abort(403)` en cas de discordance. Sans ce contrôle, un utilisateur pouvait modifier ou supprimer la demande de n'importe qui en devinant l'entier `id_demande` dans l'URL — faille classique de type *Insecure Direct Object Reference*. Dans `conge_annuler`, le SELECT préalable a également été ajouté (la route supprimait directement sans même charger l'enregistrement).

**Mode debug contrôlé par variable d'environnement.** `app.run(debug=True)` était codé en dur. Remplacé par `debug=os.getenv("FLASK_DEBUG", "0") == "1"` : le mode debug est désactivé par défaut et ne s'active qu'en posant `FLASK_DEBUG=1` dans `.env`. En mode debug actif, Werkzeug expose une console Python interactive dans le navigateur, permettant l'exécution de code arbitraire.

**Masquage des erreurs base.** Les blocs `except` flashaient `str(exc)` directement vers le template, exposant noms de tables et de contraintes MySQL. Désormais l'exception est loggée côté serveur (`app.logger.error(exc)`) et le template reçoit un message générique. Pour `conge_valider`, le message reste domaine-métier : *"Solde insuffisant ou contrainte violée — validation refusée."*

**Cache de l'utilisateur courant dans `flask.g`.** `_current_user_id()` était appelé plusieurs fois par requête (via `context_processor` + vues individuelles), provoquant des accès session/base redondants. La valeur est stockée dans `g.current_user_id` dès le premier appel et réutilisée pour le reste du cycle de vie de la requête, conformément au [pattern Flask standard](https://flask.palletsprojects.com/en/stable/appcontext/#storing-data).

---
---

## 6. Bilan critique et améliorations

### Ce que nous avons réussi

Le projet répond à l'ensemble des exigences de l'énoncé : un domaine riche de six entités, une association ternaire (`EntreePlanning`), un modèle en 3FN, un script SQL ré-exécutable accompagné d'un jeu de données cohérent, les quinze requêtes demandées couvrant jointures, agrégats et sous-requêtes corrélées, et une application connectée à MySQL couvrant toutes les fonctionnalités attendues. La séparation entre la **demande de congé** (archive RH) et l'**entrée de planning** (réalité terrain) donne au modèle un réalisme proche d'un véritable outil de gestion RH, et l'intégrité est garantie à plusieurs niveaux (contraintes SQL, triggers, logique applicative).

### Limites actuelles

La validation d'une demande et la mise à jour du solde reposent sur la logique applicative (Flask) plutôt que sur des triggers/procédures stockées : un accès direct à la base contournerait cette logique. L'application ne comporte pas d'authentification réelle (l'utilisateur courant se choisit dans la barre de navigation). Le calcul du nombre de jours décomptés ne gère pas finement les jours fériés et les week-ends.

### Améliorations envisagées

Plusieurs pistes prolongeraient le projet : déplacer la génération des entrées de planning et la décrémentation du solde dans des **procédures stockées / triggers** pour garantir l'intégrité quelle que soit la voie d'accès ; ajouter une **authentification** et une gestion des rôles (employé / manager / RH) ; intégrer un **calendrier des jours fériés** pour fiabiliser le décompte ; et ajouter des **notifications** lors de la soumission ou de la validation d'une demande.

*[Chaque membre peut compléter cette section avec le recul propre à sa partie.]*

---

## 7. Annexes et livrables

### Contenu du dépôt GitHub

| Fichier / Dossier | Contenu | Format |
|---|---|---|
| `rapport.pdf` (issu de ce `rapport.md`) | Rapport complet : domaine, règles métier, dictionnaire, MCD, MLD | PDF |
| `script_creation.sql` | DDL + DML en un seul fichier | SQL |
| `requetes.sql` | Les 15 requêtes R1–R15 | SQL |
| `sql/` | DDL éclaté, un fichier par table + `run_all.sql` | SQL |
| `src/` | Code source de l'application Flask | Python / HTML |
| `README.md` | Instructions de lancement, domaine, règles, dictionnaire | Texte |
| `MCD.mermaid`, `mcd.md`, `MLD.txt`, `dictionnaire.md` | Artefacts de modélisation | Markdown / texte |
| `BENHADDYA_BADOZ_AZDAD_ProjetBDD_Video` | Vidéo de présentation (12 min max) | Panopto |

### Instructions de lancement (résumé)

1. Exécuter `script_creation.sql` dans MySQL Workbench (crée la base `planning_entreprise`, les 6 tables, contraintes, triggers et données).
2. `cd src` → `pip install -r requirements.txt` → copier `.env.example` en `.env` et renseigner `DB_PASSWORD`.
3. `python app.py` puis ouvrir http://localhost:5000.

### Rappel — Vidéo de présentation (obligatoire)

La vidéo (12 min max, déposée sur Panopto via Teams) doit présenter : la **conception** (choix de modélisation, cardinalités, justification 3FN — 3–4 min), le **modèle physique** (contenu de tables, intégrité à l'insertion, comportement en cas de modification/suppression d'un enregistrement référencé — 2–3 min), une **démonstration** (requêtes dans Workbench + application Flask — 4–5 min) et le **bilan critique**. **Les trois membres doivent apparaître et intervenir**, sous peine d'un 0/20 pour le membre absent.
