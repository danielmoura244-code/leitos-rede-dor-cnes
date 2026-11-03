# Leitos hospitalares e aquisições da Rede D'Or (CNES/DataSUS)

Monta a tabela usada para calcular o **HHI de leitos por região de saúde**
antes e depois de cada aquisição de hospital pela Rede D'Or:

> leitos de cada hospital, mês a mês, com município, região de saúde e dono
> (CNPJ e razão social), marcando os hospitais do grupo Rede D'Or.

Tudo vem de dados públicos e sem login: FTP do DataSUS, dados abertos da CVM,
API de dados abertos do Ministério da Saúde e BrasilAPI (dados da Receita).
Não precisa de conta no Google Cloud/BigQuery.

## Como reproduzir

Requisitos: R (>= 4.4) e os pacotes abaixo.

```r
install.packages(c("data.table", "jsonlite", "remotes"))
remotes::install_github("rfsaldanha/microdatasus")   # lê os arquivos .dbc do DataSUS
```

Rode os scripts **da raiz do projeto**, nesta ordem:

```bash
Rscript codigo/01_cvm_rede_dor.R
Rscript codigo/02_regioes_saude.R
Rscript codigo/03_baixa_cnes.R
Rscript codigo/04_nomes_e_razao_social.R
Rscript codigo/05_tabela_leitos.R
```

Os arquivos baixados ficam em `dados/brutos/` (fora do git) e servem de
cache: rodar de novo não baixa nem consulta outra vez.

## Etapas

| Script | O que faz | Saída (`dados/`) |
|---|---|---|
| `01_cvm_rede_dor.R` | Baixa o Formulário de Referência (FRE) e os documentos eventuais (IPE) da CVM e filtra a Rede D'Or (CNPJ 06.047.087/0001-39) | `rede_dor_controladas.csv`, `rede_dor_fatos_relevantes.csv` |
| `02_regioes_saude.R` | Tabela município → região de saúde da base territorial do DataSUS | `municipio_regiao_saude.csv` |
| `03_baixa_cnes.R` | Baixa CNES-LT (leitos) e CNES-ST (estabelecimentos) das UFs das aquisições, nos meses pedidos, e guarda todos os estabelecimentos das regiões de saúde envolvidas | `cnes_leitos.csv`, `cnes_estabelecimentos.csv`, `aquisicoes_competencias.csv` |
| `04_nomes_e_razao_social.R` | Nome do hospital (API CNES) e razão social dos CNPJs (BrasilAPI) | `cnes_nomes.csv`, `cnpj_nomes.csv` |
| `05_tabela_leitos.R` | Junta tudo na tabela final | **`leitos_hospital_mes.csv`** |

## Entrada: `aquisicoes.csv`

Lista das aquisições (hospital, UF, código IBGE de 6 dígitos do município e
data do anúncio). É um **rascunho** montado a partir dos fatos relevantes da
Rede D'Or na CVM (`dados/rede_dor_fatos_relevantes.csv`) e de notícias; a
coluna `fonte` diz de onde veio cada data e `observacao` aponta o que conferir.
Para incluir/corrigir uma aquisição basta editar esse arquivo e rodar de novo
os scripts 03 a 05.

Os meses baixados são definidos em `MESES` no início de `03_baixa_cnes.R`:
o padrão é `c(-1, 12)` (mês anterior ao anúncio e 12 meses depois). Para a
série mês a mês completa, troque por `-1:12`.

## Tabela final: `dados/leitos_hospital_mes.csv`

Uma linha por hospital × mês (competência), só para estabelecimentos com leitos.

| Coluna | Descrição |
|---|---|
| `competencia` | AAAAMM do CNES |
| `cod_regiao_saude`, `regiao_saude` | região de saúde (mercado do HHI) |
| `uf`, `cod_municipio`, `municipio` | localização (código IBGE de 6 dígitos) |
| `cnes`, `nome_fantasia`, `tp_unid` | estabelecimento e tipo de unidade (05 = hospital geral, 07 = hospital especializado) |
| `leitos_existentes`, `leitos_sus`, `leitos_nao_sus` | soma de todos os tipos de leito do CNES-LT |
| `cnpj_dono`, `razao_social_dono` | CNPJ da mantenedora, ou do próprio estabelecimento quando não há mantenedora |
| `cnpj_estabelecimento`, `cnpj_mantenedora` | os dois CNPJs como vêm no CNES |
| `rede_dor_cvm` | `TRUE` se a raiz (8 dígitos) de um dos CNPJs está entre as controladas da Rede D'Or no FRE (ou é a própria Rede D'Or) |
| `primeiro_ano_fre` | primeiro ano em que essa raiz aparece no FRE |

Para o HHI de uma aquisição, junte com `dados/aquisicoes_competencias.csv`
por `cod_regiao_saude` + `competencia` (`mes_rel = -1` é o antes, `12` o depois).
O HHI simulado soma os leitos do hospital comprado aos da Rede D'Or no mês -1.

## Cuidados

- `rede_dor_cvm` usa a lista de controladas **de qualquer ano** (o FRE em
  dados abertos começa em 2020). Por isso o hospital comprado já aparece
  marcado também no mês anterior à compra; use `primeiro_ano_fre` e a data
  do anúncio para separar antes/depois.
- Nem todo hospital do grupo opera com CNPJ de controlada listada no FRE
  (ex.: joint ventures como a Atlântica D'Or). Confira os hospitais comprados
  pelo `nome_fantasia`.
- Um hospital pode **mudar de código CNES** depois da compra (ex.: Hospital
  Santa Isabel, em São Paulo: CNES 2079445 antes e 4060105 depois). Não
  compare antes/depois só pelo CNES; use nome e município.
- Regiões de saúde: divisão vigente em out/2025, aplicada a todos os meses.
- Razão social e nome fantasia são os atuais (consulta de hoje às APIs), não
  os da época.
