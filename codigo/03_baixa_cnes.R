# =============================================================================
# 03_baixa_cnes.R — leitos (CNES-LT) e estabelecimentos (CNES-ST) do DataSUS
#
# Para cada aquisição de aquisicoes.csv baixa os meses definidos em MESES
# (relativos ao mês do anúncio; padrão: mês anterior e 12 meses depois) e
# guarda TODOS os estabelecimentos dos municípios da região de saúde do
# hospital comprado (o mercado relevante para o HHI).
#
# Gera:
#   dados/cnes_leitos.csv            1 linha por estabelecimento x tipo de leito x mês
#   dados/cnes_estabelecimentos.csv  1 linha por estabelecimento x mês
#
# Fonte: FTP do DataSUS (ftp.datasus.gov.br/dissemin/publicos/CNES/200508_/Dados/),
#        lido com o pacote microdatasus (que abre o formato .dbc).
# Rodar da raiz do projeto:  Rscript codigo/03_baixa_cnes.R
# =============================================================================
library(data.table)
library(microdatasus)   # remotes::install_github("rfsaldanha/microdatasus")

MESES <- c(-1, 12)      # use -1:12 para ter a série mês a mês completa
BRUTOS <- "dados/brutos/cnes"
dir.create(BRUTOS, recursive = TRUE, showWarnings = FALSE)

aq  <- fread("aquisicoes.csv", colClasses = c(cod_municipio = "character"))
reg <- fread("dados/municipio_regiao_saude.csv", colClasses = "character")

# --- 1. Que UF-meses baixar e quais municípios manter ------------------------
aq <- merge(aq, reg[, .(cod_municipio, cod_regiao_saude)], by = "cod_municipio")
soma_meses <- function(data, k) {   # "2021-06-01", -1  ->  "202105"
  d <- as.POSIXlt(as.Date(data)); d$mday <- 1; d$mon <- d$mon + k
  format(as.Date(d), "%Y%m")
}
meses <- aq[, .(mes_rel = MESES), by = .(id, uf, cod_regiao_saude, data_anuncio)]
meses[, competencia := soma_meses(data_anuncio, mes_rel)]
alvo <- unique(meses[, .(uf, competencia)])
municipios_alvo <- reg[cod_regiao_saude %in% aq$cod_regiao_saude, cod_municipio]
cat(sprintf("%d UF-meses para baixar; %d municípios em %d regiões de saúde\n",
            nrow(alvo), length(municipios_alvo), uniqueN(aq$cod_regiao_saude)))

# --- 2. Baixa (com cache em csv) ----------------------------------------------
baixa <- function(sistema, uf, competencia) {
  cache <- file.path(BRUTOS, sprintf("%s_%s_%s.csv", sistema, uf, competencia))
  if (file.exists(cache)) return(fread(cache, colClasses = "character"))
  ano <- as.integer(substr(competencia, 1, 4)); mes <- as.integer(substr(competencia, 5, 6))
  d <- as.data.table(fetch_datasus(year_start = ano, month_start = mes,
                                   year_end = ano, month_end = mes,
                                   uf = uf, information_system = sistema))
  d <- d[CODUFMUN %in% municipios_alvo]   # só a região de saúde de interesse
  fwrite(d, cache)
  d
}

leitos <- rbindlist(lapply(seq_len(nrow(alvo)), function(i)
  baixa("CNES-LT", alvo$uf[i], alvo$competencia[i])), fill = TRUE)
estab  <- rbindlist(lapply(seq_len(nrow(alvo)), function(i)
  baixa("CNES-ST", alvo$uf[i], alvo$competencia[i])), fill = TRUE)

# --- 3. Salva só as colunas úteis --------------------------------------------
leitos <- leitos[, .(competencia = COMPETEN, cnes = CNES, cod_municipio = CODUFMUN,
                     tp_leito = TP_LEITO, cod_leito = CODLEITO,
                     qt_existente = as.integer(QT_EXIST), qt_sus = as.integer(QT_SUS),
                     qt_nao_sus = as.integer(QT_NSUS))]
estab <- estab[, .(competencia = COMPETEN, cnes = CNES, cod_municipio = CODUFMUN,
                   pf_pj = PF_PJ, cnpj_estabelecimento = CPF_CNPJ,
                   niv_dep = NIV_DEP, cnpj_mantenedora = CNPJ_MAN,
                   tp_unid = TP_UNID, esfera_adm = ESFERA_A, nat_jur = NAT_JUR)]
estab <- estab[cnes %in% leitos$cnes]   # só quem tem leito interessa ao HHI
fwrite(leitos, "dados/cnes_leitos.csv")
fwrite(estab,  "dados/cnes_estabelecimentos.csv")
fwrite(meses,  "dados/aquisicoes_competencias.csv")
cat(sprintf("leitos: %d linhas | estabelecimentos: %d linhas\n", nrow(leitos), nrow(estab)))
