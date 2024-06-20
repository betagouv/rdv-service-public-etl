# rdv-service-public-etl

ETL de RDV Service Public

## Usage

Ouvrir un terminal à l’app Scalingo d’ETL : `scalingo --app rdv-service-public-etl --region osc-secnum-fr1 run bash`

Lancer l’ETL

```sh
./main.sh rdvsp prod
```

## Dev local sur Mac OS

il faut utiliser un bash plus récent que celui installé par défaut.

```sh
brew install bash
brew list bash
```

puis

```sh
/opt/homebrew/Cellar/bash/5.2.26/bin/bash main.sh rdvsp demo
```
