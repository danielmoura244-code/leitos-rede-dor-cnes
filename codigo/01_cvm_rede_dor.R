# =============================================================================
# 01_cvm_rede_dor.R — dados da Rede D'Or na CVM (dados abertos, sem login)
#
# Gera:
#   dados/rede_dor_controladas.csv      empresas controladas/coligadas, por ano
#                                       do Formulário de Referência (FRE)
#   dados/rede_dor_fatos_relevantes.csv todos os fatos relevantes da companhia
#                                       (data + assunto + link), para achar as
#                                       datas de anúncio das aquisições
#
# Fonte: https://dados.cvm.gov.br/dataset/cia_aberta-doc-fre
#        https://dados.cvm.gov.br/dataset/cia_aberta-doc-ipe
# Rodar da raiz do projeto:  Rscript codigo/01_cvm_rede_dor.R
# =============================================================================
library(data.table)

CNPJ_REDE_DOR <- "06.047.087/0001-39"
ANOS <- 2010:2026
BRUTOS <- "dados/brutos/cvm"
dir.create(BRUTOS, recursive = TRUE, showWarnings = FALSE)

# baixa o zip de um ano (se ainda não baixado) e lê um csv de dentro dele
le_cvm <- function(tipo, ano, arquivo_csv) {
  url <- sprintf("https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/%s/DADOS/%s_cia_aberta_%d.zip",
                 tipo, tolower(tipo), ano)
  zip <- file.path(BRUTOS, basename(url))
  if (!file.exists(zip)) {
    ok <- tryCatch({ download.file(url, zip, mode = "wb", quiet = TRUE); TRUE },
                   error = function(e) FALSE, warning = function(w) FALSE)
    if (!ok) { unlink(zip); return(NULL) }   # ano ainda não publicado
  }
  if (!arquivo_csv %in% unzip(zip, list = TRUE)$Name) return(NULL)
  d <- suppressWarnings(fread(file = unzip(zip, arquivo_csv, exdir = tempdir()),
                              encoding = "Latin-1", colClasses = "character"))
  for (j in names(d)) set(d, j = j, value = enc2utf8(d[[j]]))   # grava em UTF-8
  d
}

# --- 1. Controladas (FRE, item "participação em sociedades") ----------------
ctrl <- rbindlist(lapply(ANOS, function(a)
  le_cvm("FRE", a, sprintf("fre_cia_aberta_participacao_sociedade_%d.csv", a))),
  fill = TRUE)
ctrl <- ctrl[CNPJ_Companhia == CNPJ_REDE_DOR]
# fica só a última versão entregue de cada data de referência
ctrl[, Versao := as.integer(Versao)]
ctrl <- ctrl[ctrl[, .I[Versao == max(Versao)], by = Data_Referencia]$V1]
ctrl[, cnpj := sprintf("%014s", gsub("\\D", "", CNPJ))]
ctrl[, cnpj := gsub(" ", "0", cnpj)]
ctrl[cnpj == "00000000000000", cnpj := NA]   # controladas no exterior não têm CNPJ
ctrl[, cnpj_raiz := substr(cnpj, 1, 8)]
ctrl <- ctrl[, .(ano_referencia = substr(Data_Referencia, 1, 4), razao_social = Razao_Social,
                 cnpj, cnpj_raiz, tipo_sociedade = Tipo_Sociedade,
                 participacao_pct = Participacao_Emissor,
                 municipio_sede = Municipio_Sede, uf_sede = UF_Sede)]
setorder(ctrl, ano_referencia, razao_social)
fwrite(ctrl, "dados/rede_dor_controladas.csv")
cat(sprintf("controladas: %d linhas, %d CNPJs distintos, anos %s\n", nrow(ctrl),
            uniqueN(ctrl$cnpj), paste(unique(ctrl$ano_referencia), collapse = ", ")))

# --- 2. Fatos relevantes (IPE) ----------------------------------------------
ipe <- rbindlist(lapply(ANOS, function(a)
  le_cvm("IPE", a, sprintf("ipe_cia_aberta_%d.csv", a))), fill = TRUE)
fr <- ipe[CNPJ_Companhia == CNPJ_REDE_DOR & Categoria == "Fato Relevante",
          .(data_referencia = Data_Referencia, data_entrega = Data_Entrega,
            assunto = Assunto, link = Link_Download)]
fr <- unique(fr, by = c("data_entrega", "assunto"))
setorder(fr, data_entrega)
fwrite(fr, "dados/rede_dor_fatos_relevantes.csv")
cat(sprintf("fatos relevantes: %d (de %s a %s)\n", nrow(fr),
            min(fr$data_entrega), max(fr$data_entrega)))
