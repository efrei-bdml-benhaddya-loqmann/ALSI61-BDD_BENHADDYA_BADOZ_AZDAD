# MyEfrei Congés - Réservation de congés - Projet BDD ALSI61

Application web de réservation de congés adossée à une base MySQL.
Un employé réserve, modifie et annule ses demandes de congé ; son manager les valide ou les refuse ; la validation décompte automatiquement le solde.

## Prérequis

- MySQL 8.x
- Python 3.11+

## 1. Créer la base de données

Depuis MySQL Workbench : ouvrir `script_creation.sql` et l'exécuter (⚡).

Ou en ligne de commande :

```bash
mysql -u root -p < script_creation.sql
```

Ce script crée la base `planning_entreprise`, les 6 tables, les contraintes, les triggers, et insère le jeu de données. Vérification : `SELECT COUNT(*) FROM EntreePlanning;` doit renvoyer 51.

## 2. Lancer l'application

```bash
cd src
pip install -r requirements.txt
copy .env.example .env        # Windows
# cp .env.example .env        # macOS / Linux
```

Éditer `.env` et renseigner `DB_PASSWORD` (ton mot de passe MySQL). Modifier egalement `FLASK_SECRET_KEY` (bonne pratique permettant simplement de sécuriser les données de l'application).

```bash
python app.py
```

Ouvrir http://localhost:5000

## Utilisation

- **Connecté en tant que** (navbar) : choisir l'employé courant — pas d'authentification.
- **Mes demandes** : solde, liste des demandes, filtre par statut.
- **Réserver** : créer une demande (type, dates, motif).
- **Détail** : modifier / annuler une demande en attente ; valider / refuser si on est le manager du demandeur.
- **Calendrier équipe** : grille hebdomadaire colorée par statut.
- **Statistiques** : demandes par statut, top demandeurs, répartition par type.

## Structure

```
.
├── script_creation.sql   # DDL + DML en un seul fichier (livrable)
├── requetes.sql          # 15 requêtes R1–R15
├── sql/                  # DDL éclaté, un fichier par table + run_all.sql
├── src/
│   ├── app.py            # assemblage : factory + context_processor + routage
│   ├── db.py             # connexion MySQL + helpers query()/execute()
│   ├── helpers.py        # logique partagée (utilisateur courant, parsing, calculs)
│   ├── routes/           # une vue Flask par fichier (mes_conges, conge_*, calendrier, stats…)
│   ├── requirements.txt
│   ├── .env.example
│   ├── static/           # feuille de style (design tokens)
│   └── templates/        # vues Jinja2 + Bootstrap
├── MCD.mermaid           # modèle conceptuel
├── MLD.md                # modèle logique
└── dictionnaire.md       # dictionnaire de données
```

## Domaine et règles métier

- 6 entités : `Service`, `Employe`, `StatutJour`, `EntreePlanning`, `DemandeConge`, `SoldeConge`.
- Un employé appartient à un service et a au plus un manager (auto-référence).
- `EntreePlanning` = association ternaire Employé × Jour × Statut ; unicité `(employé, date, demi-journée)`.
- `date_debut ≤ date_fin` sur toute demande (CHECK).
- Le solde ne peut pas être négatif : `jours_acquis − jours_pris ≥ 0` (CHECK).
- Code service de la forme `S` + 2 chiffres (CHECK).
