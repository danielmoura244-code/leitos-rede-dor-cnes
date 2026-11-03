# =============================================================================
# 05_tabela_leitos.R — a tabela única para o HHI
#
# 1 linha por hospital x mês, com: leitos, município, região de saúde, dono
# (CNPJ e razão social) e se o CNPJ pertence ao grupo Rede D'Or segundo o
# Formulário de Referência da CVM.
#
# Dono = CNPJ da mantenedora quando o estabelecimento tem mantenedora;
#        senão, o CNPJ do próprio estabelecimento.
#
# Gera: dados/leitos_hospital_mes.csv
# Rodar da raiz do projeto:  Rscript codigo/05_tabela_leitos.R
# =============================================================================
library(data.table)

le <- function(f) fread(f, colClasses = "character", encoding = "UTF-8")
leitos <- le("dados/cnes_leitos.csv")
estab  <- le("dados/cnes_estabelecimentos.csv")
reg    <- le("dados/municipio_regiao_saude.csv")
nomes  <- le("dados/cnes_nomes.csv")
razao  <- le("dados/cnpj_nomes.csv")
ctrl   <- le("dados/rede_dor_controladas.csv")

# --- 1. Soma os leitos de cada hospital no mês (todos os tipos de leito) -----
leitos[, (c("qt_existente", "qt_sus", "qt_nao_sus")) := lapply(.SD, as.integer),
       .SDcols = c("qt_existente", "qt_sus", "qt_nao_sus")]
tab <- leitos[, .(leitos_existentes = sum(qt_existente), leitos_sus = sum(qt_sus),
                  leitos_nao_sus = sum(qt_nao_sus)),
              by = .(competencia, cnes, cod_municipio)]

# --- 2. Dono, localização e nomes --------------------------------------------
estab <- unique(estab, by = c("competencia", "cnes"))
tab <- merge(tab, estab[, .(competencia, cnes, tp_unid, cnpj_estabelecimento, cnpj_mantenedora)],
             by = c("competencia", "cnes"), all.x = TRUE)
valido <- function(x) !is.na(x) & nchar(x) == 14 & x != "00000000000000"
tab[, cnpj_dono := fifelse(valido(cnpj_mantenedora), cnpj_mantenedora,
                           fifelse(valido(cnpj_estabelecimento), cnpj_estabelecimento, NA_character_))]
tab <- merge(tab, razao[, .(cnpj_dono = cnpj, razao_social_dono = razao_social)],
             by = "cnpj_dono", all.x = TRUE)
tab <- merge(tab, nomes, by = "cnes", all.x = TRUE)
tab <- merge(tab, reg[, .(cod_municipio, municipio, uf, cod_regiao_saude, regiao_saude)],
             by = "cod_municipio", all.x = TRUE)

# --- 3. Pertence à Rede D'Or? (raiz do CNPJ na lista de controladas da CVM) --
raizes <- ctrl[!is.na(cnpj_raiz) & cnpj_raiz != "", .(primeiro_ano_fre = min(ano_referencia)), by = cnpj_raiz]
raizes <- rbind(raizes, data.table(cnpj_raiz = "06047087", primeiro_ano_fre = "2019"))  # a própria Rede D'Or
raizes <- raizes[, .(primeiro_ano_fre = min(primeiro_ano_fre)), by = cnpj_raiz]
tab[, raiz_est := fifelse(valido(cnpj_estabelecimento), substr(cnpj_estabelecimento, 1, 8), NA_character_)]
tab[, raiz_man := fifelse(valido(cnpj_mantenedora), substr(cnpj_mantenedora, 1, 8), NA_character_)]
tab <- merge(tab, raizes[, .(raiz_est = cnpj_raiz, ano_fre_est = primeiro_ano_fre)], by = "raiz_est", all.x = TRUE)
tab <- merge(tab, raizes[, .(raiz_man = cnpj_raiz, ano_fre_man = primeiro_ano_fre)], by = "raiz_man", all.x = TRUE)
tab[, primeiro_ano_fre := pmin(ano_fre_est, ano_fre_man, na.rm = TRUE)]
tab[, rede_dor_cvm := !is.na(primeiro_ano_fre)]

# --- 4. Salva -----------------------------------------------------------------
tab <- tab[, .(competencia, cod_regiao_saude, regiao_saude, uf, cod_municipio, municipio,
               cnes, nome_fantasia, tp_unid, leitos_existentes, leitos_sus, leitos_nao_sus,
               cnpj_dono, razao_social_dono, cnpj_estabelecimento, cnpj_mantenedora,
               rede_dor_cvm, primeiro_ano_fre)]
setorder(tab, cod_regiao_saude, competencia, -leitos_existentes)
fwrite(tab, "dados/leitos_hospital_mes.csv")
cat(sprintf("%d linhas | %d hospitais | %d regiões | %d linhas marcadas como Rede D'Or\n",
            nrow(tab), uniqueN(tab$cnes), uniqueN(tab$cod_regiao_saude), sum(tab$rede_dor_cvm)))
