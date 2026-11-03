# =============================================================================
# 04_nomes_e_razao_social.R — nome do hospital e razão social do dono
#
# Os arquivos .dbc do CNES não trazem nomes. Este script consulta, só para os
# estabelecimentos que têm leitos:
#   - API de dados abertos do Ministério da Saúde -> nome fantasia (por CNES)
#   - BrasilAPI (dados da Receita Federal)        -> razão social (por CNPJ)
#
# Gera (e reusa como cache, então pode rodar de novo sem refazer consultas):
#   dados/cnes_nomes.csv   cnes, nome_fantasia, razao_social_cnes
#   dados/cnpj_nomes.csv   cnpj, razao_social
#
# Rodar da raiz do projeto:  Rscript codigo/04_nomes_e_razao_social.R
# =============================================================================
library(data.table)
library(jsonlite)

leitos <- fread("dados/cnes_leitos.csv", colClasses = "character")
estab  <- fread("dados/cnes_estabelecimentos.csv", colClasses = "character")
estab  <- estab[cnes %in% leitos$cnes]

# consulta uma URL e devolve a lista JSON (ou NULL se falhar)
consulta <- function(url) {
  Sys.sleep(0.3)   # gentileza com as APIs públicas
  tryCatch(fromJSON(url), error = function(e) NULL)
}
# completa um cache csv com as chaves que ainda faltam
completa_cache <- function(arquivo, chaves, busca) {
  cache <- if (file.exists(arquivo)) fread(arquivo, colClasses = "character") else NULL
  if (!is.null(cache)) cache <- cache[!is.na(cache[[2]]) & cache[[2]] != ""]   # tenta de novo o que falhou
  faltam <- setdiff(chaves, cache[[1]])
  cat(sprintf("%s: %d em cache, %d a consultar\n", arquivo, length(chaves) - length(faltam), length(faltam)))
  for (k in faltam) {
    cache <- rbind(cache, busca(k), fill = TRUE)
    fwrite(cache, arquivo)   # salva a cada consulta: dá para interromper e retomar
  }
}

# --- 1. Nome do estabelecimento (por CNES) -----------------------------------
completa_cache("dados/cnes_nomes.csv", unique(estab$cnes), function(cnes) {
  r <- consulta(paste0("https://apidadosabertos.saude.gov.br/cnes/estabelecimentos/", as.integer(cnes)))
  data.table(cnes = cnes, nome_fantasia = r$nome_fantasia %||% NA_character_,
             razao_social_cnes = r$nome_razao_social %||% NA_character_)
})

# --- 2. Razão social (por CNPJ do estabelecimento e da mantenedora) ----------
cnpjs <- unique(c(estab$cnpj_estabelecimento, estab$cnpj_mantenedora))
cnpjs <- cnpjs[nchar(cnpjs) == 14 & cnpjs != "00000000000000"]
completa_cache("dados/cnpj_nomes.csv", cnpjs, function(cnpj) {
  r <- consulta(paste0("https://brasilapi.com.br/api/cnpj/v1/", cnpj))
  data.table(cnpj = cnpj, razao_social = r$razao_social %||% NA_character_)
})
