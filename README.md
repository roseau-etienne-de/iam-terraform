# iam-terraform

Configuration Terraform de l'IAM GCP pour les services UX Data & Perf Acquisition.
Elle a été rassemblée dans un terraform pour permettre d'améliorer l'organisation, la sécurité, gagner du temps et réduire le nombre de conflits.

1. [Vue d'ensemble](#1-vue-densemble)
2. [Déploiement](#2-déploiement)
3. [Configuration IAM](#3-configuration-iam)
4. [Architecture Terraform](#4-architecture-terraform)
5. [Exceptions IAM](#5-exceptions-iam)
6. [Troubleshoot](#6-troubleshoot) 

# 1. Vue d'ensemble

### Architecture
Ce repo gère l'IAM (Identity and Access Management) sur GCP pour les utilisateurs :
- **Internes** : via des custom roles (Perf Digitale Admin|User V3)
- **Externes** : via des configurations JSON centralisées

**Projets concernés :**
- engie-b2c-cloud (principal)
- engie-b2c-cloud-ehs
- gaz-tarif-reglemente-noprod

## Service Account CICD
`sa-iam-terraform-cicd@engie-b2c-cloud.iam.gserviceaccount.com`

Rôles requis :
- BigQuery Admin
- Cloud Quotas Admin
- Project IAM Admin
- Role Viewer
- Storage Admin

Pour **ne pas utiliser de clé**, le service account se connecte via **Workload Identity Federation** à gcp.

# 2. Déploiement

La configuration se fait en local après création d'une branche dédiée. Les changements sont push sur le repo et lors de la Pull Request, la CICD va afficher la future configuration GCP. Si celle-ci convient, vous pouvez merger. Cela activera le deploiement de la nouvelle config IAM sur GCP.

## Workflows CICD

> [!NOTE]
> Afin de protéger le code, la PR est obligatoire : les push vers master sont bloqués.

| Événement | Action | Description |
|-----------|--------|-------------|
| Pull Request | `terraform plan` | Affiche les changements sur Github. S'ils vous conviennent, vous pouvez merge.
| Merge vers master | `terraform apply` | Applique les changements (mergez seulement après vérification précise du `terraform plan`).

## Setup

**Prerequis :** [installer terraform](https://developer.hashicorp.com/terraform/install)

La première fois, sur votre local,
1. Clonez le repo et créez une branche
2. Exécutez `terraform init`

## Usage standard *(ajouter ou supprimer un user)*

Voici les étapes que l'administrateur doit suivre :

> [!IMPORTANT]
> Si vous ajoutez un utilisateur, celui-ci doit avoir un compte @engie.com **Gaia** (relié à Okta, exemple : <nom>@engie.com ou <nom>@external.engie.com).<br>

1. ⚠️ Pour chaque modification, créez une nouvelle branche. Utilisez les préfixes `add/` ou `del/`.
2. Pour ajouter ou supprimer un utilisateur, il faut modifier un des fichiers de config (dans le dossier `iam_config`).
   
> [!TIP]
> par exemple, pour ajouter un **utilisateur interne** en tant que **User** *(rôle : Custom - Perf Digitale - User V3)* :
> - allez dans le fichier<br>
> `iam_config/internal/custom_roles/members/internal_members_user.txt`.
> - ajouter l'utilisateur, en respectant la nomenclature `user:<nom@engie.com>` et l'ordre alphabétique du fichier.
> - enregistrez.
    
3. Commit et push.
4. Dans Github, effectuez la Pull Request (vers master). Le `terraform plan` s'active automatiquement et s'affiche dans les commentaires de la PR.
5. ⚠️ Vérifiez attentivement les changements affichés dans le `terraform plan`.
6. Si ils vous conviennent : **Mergez**.<br>
  Sinon, modifiez votre branche locale, commit et push. Un nouveau `terraform plan` s'affichera automatiquement sur la même PR.
 

# 3. Configuration IAM

```bash
iam_config
├── external
│   ├── custom_policies.json.tpl              # json listant les clients et leurs paramètres d'accès 
│   └── project_lvl_roles.json                # custom rôles gcp (niveau projet) dédiés aux externes
└── internal
    ├── custom_roles
    │   ├── members
    │   │   ├── internal_members_admin.txt    # liste des utilisateurs ayant le role `Custom - Perf Digitale - Admin V3`
    │   │   └── internal_members_user.txt.    # liste des utilisateurs ayant le role `Custom - Perf Digitale - User V3`
    │   └── permissions
    │       ├── permissions_perf_admin.txt    # liste des permissions affiliées au role `Custom - Perf Digitale - Admin V3`
    │       └── permissions_perf_user.txt     # liste des permissions affiliées au role `Custom - Perf Digitale - User V3` 
    ├── exceptionnal_full_access
    │   └── internal_exception_principals.txt # liste des utilisateurs sans restrictions sur certaines structures GCP
    ├── specific_internal_roles.json          # liste des utilisateurs + roles attribués à titre exceptionnel
    └── test_users.txt                        # liste nominatives des utilisateurs test
```

## Accès Internes

Au sein du dossier `iam_config/`, les paramètres d'accès et de permissions sont rassemblés dans le dossier `internal/`.

### Rôles internes
- Custom - Perf Digitale - Admin V3
- Custom - Perf Digitale - User V3

Ces rôles sont naturellement limités sur certaines structures : 
- le bucket `digital_value`
- le dataset `DV_data_dashboard`

Cette limite est retirée, pour les utilisateurs présents dans le fichier *iam_config/internal/exceptionnal_full_access/*`internal_exception_principals.txt`.

Exceptionnellement, d'autres rôles sont affiliés à certains users. La config est rassemblée dans le json *iam_config/internal/*`specific_internal_roles.json`.

## Accès Externes

- Les paramètres affiliés aux utilisateurs externes sont rassemblés dans ce fichier : *iam_config/external/*`custom_policies.json.tpl`.<br>
C'est un dictionnaire permettant de grouper pour chaque client, leurs rôles et leurs structures GCP.<br>
*exemple :*
```json
{
    "kwanko": {
        "project_lvl_roles": [ 
            "projects/${project_id}/roles/CustomBucketRole"
        ],
        "gcs_role": "roles/storage.objectUser",
        "buckets": [ "kwanko" ],
        "members": [
            "user:benoit.trottein@kwanko.com",
            "user:jeanne.haurogne@kwanko.com"
        ]
    },
    ...
}
```

- Les custom rôles dédiés aux **users externes** sont rassemblés dans le json `project_lvl_roles.json`.<br>
Ces 2 rôles se composent d'une permission chacun : 

| Role name | Permission | Fonction |
|-----------|------------|----------|
| Custom - External - Bucket | storage.buckets.list | Permet de lister les buckets |
| Custom - External - BigQuery | bigquery.jobs.create | Permet d'exécuter des requetes sur BQ |

- Ces roles sont ensuite limités aux clients et à leur ressources respectives (rassemblées dans `custom_policies.json.tpl`).<br>
✨ Ainsi, les **externes** ont uniquement accès à leur buckets et leurs datasets BQ. ✨

# 4. Architecture Terraform

Ce chapitre décrit l'attribution des paramètres IAM aux différents principals (Service accounts et utilisateurs).

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| 00-main.tf | Configuration provider |
| 01-variables.tf | Variables |
| 02-locals.tf | Valeurs locales |
| 03-iam.tf ⚠️ |  Ressources IAM (c'est la config principale) |
| 04-bq-quotas.tf | Quotas BigQuery |
| 99-outputs.tf | Outputs |

## Focus : 02-locals.tf

Ce fichier dynamise et transforme les paramètres rassemblés dans le dossier `iam-config` en variables exploitables par la config terraform. Celle-ci est responsable de l'execution (Chapitre ci-dessous : **03-iam.tf**).

## Focus : 03-iam.tf

### Ressources dédiées aux Internes

Ici sont décrites les ressources terraform et leur fonction.

#### Création des Custom roles internes

```bash
# création du rôle "CustomPerfDigitalAdminV3" à partir du fichier permissions_perf_admin.txt
resource "google_project_iam_custom_role" "CustomPerfDigitalAdminV3" {
... }

# création du rôle "CustomPerfDigitalUserV3" à partir du fichier permissions_perf_user.txt
resource "google_project_iam_custom_role" "CustomPerfDigitalUserV3" {
... }
```

#### Attribution des roles aux users internes

```bash
# Lie le rôle CustomPerfDigitalAdminV3 aux users listés dans internal_members_admin.txt
resource "google_project_iam_binding" "CustomPerfDigitalAdminV3" {
...
  dynamic "condition"
  # Introduit une interdiction d'accès à certains buckets et datasets, 
  # sauf pour les users listés dans internal_exception_principals.txt
... }

# Même chose pour le rôle CustomPerfDigitalUserV3 (internal_members_admin.txt)
resource "google_project_iam_binding" "CustomPerfDigitalUserV3" {
...
  dynamic "condition"
... }
```

#### Exceptions (internes)

```bash
# Ajoute des rôles spécifiques pour certains besoins (depuis le fichier specific_internal_roles.json)
resource "google_project_iam_member" "SpecificInternalRoles" {
... }
```

### Ressources dédiées aux Externes

#### Création des Custom roles (externes)

```bash
# Crée les rôles dédiés aux externes depuis le fichier project_lvl_roles
resource "google_project_iam_custom_role" "ExternalProjectLvl" {
... }
```

#### Attribution des custom roles aux externes

```bash
# Lie les customs rôles créés ci-dessus aux users externes (custom_policies.json.tpl)
resource "google_project_iam_binding" "ProjectCustomRoleForExternal" {
... }
```

#### Attribution des roles officiels GCP aux externes

```bash
# Lie les roles GCP à leur client respectifs via custom_policies.json.tpl
resource "google_storage_bucket_iam_binding" "binding" {
... }

resource "google_bigquery_dataset_iam_binding" "binding" {
... }
```

# 5. Exceptions IAM

Les utilisateurs listés dans le fichier *iam_config/internal/exceptionnal_full_access/*`internal_exception_principals.txt` bénéficie d'un accès sans conditions aux resources (notament les resources externes).<br>
Pour certains cas d'usage précis, certains utilisateurs ont des accès/rôles supplémentaires.
Ceux-ci sont listés dans ce fichier */Users/hl6628/Code/terraform-engie/iam-terraform/iam_config/internal/*`specific_internal_roles.json`.<br>

Ci-dessous sont listés les users et les UC nécessitant des roles supplémentaires.
  - younes.bissani@external.engie.com
    - Besoin de créer des pocs et de tester certaine features sur GCP.

# 6. Troubleshoot

## Probleme `terraform apply`

Après avoir validé la Pull Request, si la Github action **terraform-apply** plante, relisez bien l'erreur affichée dans la Github action.<br>
Vous pouvez pull la master et corriger l'erreur sur une nouvelle branche.


## Quotas Big Query

Le changement de quota big query (consumption per user per day) est instable avec Terraform.

Pb : terraform ne tolère pas le changement de plus de 10% d'un quota.
```bash
Error: Error updating QuotaPreference "projects/engie-b2c-cloud-ehs/locations/global/quotaPreferences/333e4080-74c0-438c-9759-1301aaf73fa4": googleapi: Error 400: com.google.apps.framework.request.StatusException: <eye3 title='FAILED_PRECONDITION'/> generic::FAILED_PRECONDITION: The quota override for quota unit '1/d/{project}/{user}' with dimensions {} on metric 'bigquery.googleapis.com/quota/query/usage' decreases effective quota unsafely. New effective limit 4194304 decreases current effective limit 5242880 by more than 10.000000 percent.
```

## Cas Looker

Lorsqu'un **externe** veut accéder depuis son Looker Studio au projet **engie-b2c-cloud**, il peut ne pas y avoir accès malgré ses roles legacy (terraform : `bigquery.jobUser` sur le projet et `bigquery.dataViewer` sur chaque dataset pertinent).
Il  a besoin du rôle `roles/bigquery.readSessionUser` au niveau du projet. Ainsi, il faut ajouter ce rôle dans le fichier de config dédié aux externes : `custom_policies.json.tpl`.<br>
_exemple :_
``` json
# custom_policies.json.tpl

"adsup": {
    "project_lvl_roles": [
        "projects/${project_id}/roles/CustomBigQueryRole",
        "roles/bigquery.readSessionUser"
    ],
```
