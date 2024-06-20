# rdv-service-public-etl

ETL de RDV Service Public

## Usage

`bundle exec ruby main.rb --app rdvi --env demo --schema public`

## Dev local

### Préparation

- `cp .env.sample .env` et définir la variable DATABASE_URL
- `createdb rdv-sp-etl`

### Spécificités Mac OS

il faut utiliser un bash plus récent que celui installé par défaut.

```sh
brew install bash
brew list bash
```

puis

```sh
/opt/homebrew/Cellar/bash/5.2.26/bin/bash main.sh rdvsp demo
```
