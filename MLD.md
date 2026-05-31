# Modèle Logique de Données (MLD)

**Projet BDD ALSI61 — Outil de gestion de planning**

> **Notation :** `NomTable(**cle_primaire**, attribut1, attribut2, #cle_etrangere)`

---

## 1. Service

Service(**id_service**, code_service, libelle)

**Contraintes :**
- **PK** : `id_service`
- **UNIQUE** : `code_service`
- **CHECK** : `code_service REGEXP '^S[0-9]{2}$'`

---

## 2. Employe

Employe(**id_employe**, nom, prenom, email, date_embauche, #id_service, #id_manager)

**Contraintes :**
- **PK** : `id_employe`
- **FK** : `id_service` → `Service(id_service)`
- **FK** : `id_manager` → `Employe(id_employe)` *(auto-référence, NULL autorisé = sommet hiérarchie)*
- **UNIQUE** : `email`
- **NOT NULL** : `nom`, `prenom`, `email`, `date_embauche`, `id_service`

---

## 3. StatutJour

StatutJour(**id_statut**, libelle, code, decompte_solde)

**Contraintes :**
- **PK** : `id_statut`
- **UNIQUE** : `code`
- **CHECK** : `code IN ('CP', 'RTT', 'TT', 'BUR', 'MAL', 'FOR')`
- **NOT NULL** : `libelle`, `code`, `decompte_solde`
- **DEFAULT** `decompte_solde` : `FALSE` *(seuls CP et RTT ont TRUE)*

---

## 4. EntreePlanning

EntreePlanning(**id_entree**, date, demi_journee, #id_employe, #id_statut)

**Contraintes :**
- **PK** : `id_entree`
- **FK** : `id_employe` → `Employe(id_employe)`
- **FK** : `id_statut` → `StatutJour(id_statut)`
- **UNIQUE** : `(id_employe, date, demi_journee)`
- **CHECK** : `demi_journee IN ('matin', 'apres-midi', 'journee')`
- **NOT NULL** : `date`, `demi_journee`, `id_employe`, `id_statut`
- **TRIGGER** : `BEFORE INSERT` — bloque si conflit `'journee'` ↔ `'matin'`/`'apres-midi'` sur le même `(id_employe, date)`

**Rôle :** Association ternaire matérialisée `Employé × Jour × StatutJour`.
L'attribut `demi_journee` porte la sémantique de la ternaire.

---

## 5. DemandeConge

DemandeConge(**id_demande**, date_debut, date_fin, demi_journee_debut, demi_journee_fin,
statut_demande, date_soumission, motif, #id_employe, #id_statut, #id_manager_valideur)

**Contraintes :**
- **PK** : `id_demande`
- **FK** : `id_employe` → `Employe(id_employe)`
- **FK** : `id_statut` → `StatutJour(id_statut)`
- **FK** : `id_manager_valideur` → `Employe(id_employe)` *(NULL si pas encore traité)*
- **CHECK** : `date_debut <= date_fin`
- **CHECK** : `demi_journee_debut IN ('matin', 'apres-midi', 'journee')`
- **CHECK** : `demi_journee_fin IN ('matin', 'apres-midi', 'journee')`
- **CHECK** : `statut_demande IN ('en_attente', 'validee', 'refusee')`
- **DEFAULT** `statut_demande` : `'en_attente'`
- **DEFAULT** `date_soumission` : `CURRENT_TIMESTAMP`
- **NOT NULL** : `date_debut`, `date_fin`, `demi_journee_debut`, `demi_journee_fin`, `id_employe`, `id_statut`

**Rôle :** Archive de la demande — séparée d'`EntreePlanning` qui représente la réalité terrain.
Quand `statut_demande` passe à `'validee'`, l'app Python génère les `EntreePlanning` correspondantes.

---

## 6. SoldeConge

SoldeConge(**id_solde**, annee, jours_acquis, jours_pris, #id_employe, #id_statut)

**Contraintes :**
- **PK** : `id_solde`
- **FK** : `id_employe` → `Employe(id_employe)`
- **FK** : `id_statut` → `StatutJour(id_statut)` *(CP ou RTT uniquement en pratique)*
- **UNIQUE** : `(id_employe, id_statut, annee)`
- **CHECK** : `jours_acquis >= 0`
- **CHECK** : `jours_pris >= 0`
- **CHECK** : `jours_acquis - jours_pris >= 0` *(solde ne peut pas être négatif)*
- **NOT NULL** : `annee`, `jours_acquis`, `jours_pris`, `id_employe`, `id_statut`

---

## Règles métier supplémentaires (logique applicative)

| # | Règle |
|----|-------|
| R1 | Un employé appartient à exactement un service (`id_service` NOT NULL). |
| R2 | Un employé a au plus un manager direct (`id_manager` NULL = DG / sommet). |
| R3 | Une entrée planning est unique par `(employé, date, demi-journée)`. |
| R4 | `'journee'` et `'matin'`/`'apres-midi'` ne peuvent pas coexister le même jour pour le même employé → trigger. |
| R5 | `date_debut ≤ date_fin` sur toute demande de congé. |
| R6 | Le solde de congés ne peut pas être négatif. |
| R7 | La validation d'une demande génère les `EntreePlanning` (app Python, pas de trigger BDD). |
| R8 | La modification d'un jour précis se fait directement sur `EntreePlanning` ; la `DemandeConge` reste archive. |

---

## Dépendances d'ordre de création (DDL)

1. **Service**
2. **Employe** *(dépend de Service, auto-ref)*
3. **StatutJour**
4. **EntreePlanning** *(dépend de Employe, StatutJour)*
5. **DemandeConge** *(dépend de Employe, StatutJour)*
6. **SoldeConge** *(dépend de Employe, StatutJour)*
