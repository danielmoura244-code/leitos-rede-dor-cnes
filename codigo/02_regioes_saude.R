# =============================================================================
# 02_regioes_saude.R — município -> região de saúde (tabela territorial DataSUS)
#
# Gera: dados/municipio_regiao_saude.csv
#
# Fonte: ftp://ftp.datasus.gov.br/territorio/tabelas/  (base territorial)
# Obs.: usa a divisão de regiões de saúde vigente na versão baixada (out/2025).
# Rodar da raiz do projeto:  Rscript codigo/02_regioes_saude.R
# =============================================================================
library(data.table)

URL <- "ftp://ftp.datasus.gov.br/territorio/tabelas/2025/10-base_territorial_out25.zip"
BRUTOS <- "dados/brutos/territorio"
dir.create(BRUTOS, recursive = TRUE, showWarnings = FALSE)
zip <- file.path(BRUTOS, "base_territorial.zip")
if (!file.exists(zip)) download.file(URL, zip, mode = "wb")
unzip(zip, c("tb_municip.csv", "tb_regsaud.csv", "rl_municip_regsaud.csv", "tb_uf.csv"),
      exdir = BRUTOS)

le <- function(f) fread(file.path(BRUTOS, f), colClasses = "character", encoding = "UTF-8")
mun <- le("tb_municip.csv")[CO_STATUS == "ATIVO", .(cod_municipio = CO_MUNICIP,
                                                   cod_municipio_7 = CO_MUNICDV,
                                                   municipio = DS_NOME, CO_UF)]
uf  <- le("tb_uf.csv")[, .(CO_UF = co_uf, uf = ds_sigla)]
rel <- le("rl_municip_regsaud.csv")[, .(cod_municipio = CO_MUNICIP, cod_regiao_saude = CO_REGSAUD)]
reg <- le("tb_regsaud.csv")[, .(cod_regiao_saude = REGSAUD, regiao_saude = trimws(DS_NOME))]

out <- merge(mun, uf, by = "CO_UF")
out <- merge(out, rel, by = "cod_municipio", all.x = TRUE)
out <- merge(out, reg, by = "cod_regiao_saude", all.x = TRUE)
out <- out[, .(cod_municipio, cod_municipio_7, municipio, uf, cod_regiao_saude, regiao_saude)]
setorder(out, cod_municipio)
fwrite(out, "dados/municipio_regiao_saude.csv")
cat(sprintf("%d municípios, %d regiões de saúde, %d sem região\n",
            nrow(out), uniqueN(out$cod_regiao_saude, na.rm = TRUE),
            sum(is.na(out$cod_regiao_saude))))
