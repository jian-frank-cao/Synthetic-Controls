## Setup -----------------------------------------------------------------------
library(checkpoint)
checkpoint("2022-04-01")

library(tidyverse)
library(furrr)
plan(multisession, workers = 8)
options(future.rng.onMisuse="ignore")
options(stringsAsFactors = FALSE)
source("./R/misc.R")
source("./R/TFDTW.R")
source("./R/synth.R")
source("./R/implement.R")
source("./R/simulate.R")
source("./R/grid.search.R")
set.seed(20220407)


## Extract Results -------------------------------------------------------------
results = NULL
beta = 1
folder = "./data/res_sim/1124/"
res.files = list.files(folder)
for (res.file in res.files) {
  results = c(results, list(readRDS(paste0(folder, res.file))))
}

length = 100
shock = 0
treat_time = 60
n_mse = 10

causal_effect = c(rep(0, treat_time),
                  seq(0, shock, length.out = round(0.1*length)),
                  rep(shock, round(0.9*length - treat_time)))

# find the best grid search parameters
ind.opt = future_map2(
  results,
  as.list(res.files),
  ~{
    item = .x
    file.name = .y
    ind.dataset = tail(str_split(file.name, "_")[[1]],1)
    ind.dataset = as.numeric(gsub("([0-9]+).*$", "\\1", ind.dataset))
    neg.ratio = lapply(item, "[[", "neg.ratio") %>% do.call("c", .)
    ind.max.neg.ratio = which(neg.ratio == max(neg.ratio, na.rm = T))
    p.value = lapply(item, "[[", "p.value") %>% do.call("c", .) %>% .[ind.max.neg.ratio]
    ind.min.p.value = which(p.value == min(p.value, na.rm = T))
    ind.search = ind.max.neg.ratio[ind.min.p.value[1]]
    list(ind.dataset = ind.dataset,
         ind.search = ind.search)
  }
)

## Estimate --------------------------------------------------------------------
beta = 10
data.list = readRDS(paste0("./data/simul_data_beta_", beta, ".Rds"))

# parameters
filter.width.range = (1:9)*2+3
k.range = 4:9
step.pattern.range = list(
  # symmetricP0 = dtw::symmetricP0, # too bumpy
  # symmetricP05 = dtw::symmetricP05,
  symmetricP1 = dtw::symmetricP1,
  symmetricP2 = dtw::symmetricP2,
  # asymmetricP0 = dtw::asymmetricP0, # too bumpy
  # asymmetricP05 = dtw::asymmetricP05,
  asymmetricP1 = dtw::asymmetricP1,
  asymmetricP2 = dtw::asymmetricP2,
  typeIc = dtw::typeIc,
  # typeIcs = dtw::typeIcs,
  # typeIIc = dtw::typeIIc,  # jumps
  # typeIIIc = dtw::typeIIIc, # jumps
  # typeIVc = dtw::typeIVc,  # jumps
  typeId = dtw::typeId,
  # typeIds = dtw::typeIds,
  # typeIId = dtw::typeIId, # jumps
  mori2006 = dtw::mori2006
)
search.grid = expand.grid(filter.width.range, k.range,
                          names(step.pattern.range)) %>% 
  `colnames<-`(c("filter.width", "k", "step.pattern"))
grid.search.parallel = FALSE


args.TFDTW = list(buffer = 20, match.method = "open.end",
                  dist.quant = 0.95, 
                  window.type = "sakoechiba",
                  ## other
                  norm.method = "t",
                  step.pattern2 = dtw::asymmetricP2,
                  n.burn = 3, n.IQR = 3,
                  ma = 3, ma.na = "original",
                  default.margin = 3,
                  n.q = 1, n.r = 1)

args.synth = list(predictors = NULL,
                  special.predictors = 
                    expression(list(list(dep.var, 50:59, c("mean")),
                                    list(dep.var, 40:49, c("mean")),
                                    list(dep.var, 30:39, c("mean")))),
                  time.predictors.prior = 1:59,
                  time.optimize.ssr = 1:59)

args.TFDTW.synth = list(start.time = 1, end.time = 100, treat.time = 60,
                        args.TFDTW = args.TFDTW, args.synth = args.synth,
                        ## 2nd
                        n.mse = 10, 
                        ## other
                        # detailed.output = TRUE,
                        plot.figures = FALSE,
                        plot.path = "./figures/",
                        legend.pos = c(0.3, 0.7))

args.TFDTW.synth.all.units = list(target = "A",
                                  # data = data, 
                                  args.TFDTW.synth = args.TFDTW.synth,
                                  ## 2nd
                                  detailed.output = TRUE,
                                  # target.TFDTW = TRUE,
                                  all.units.parallel = FALSE)


results = ind.opt %>% 
  future_map(
    ~{
      item = .
      ind.dataset = item$ind.dataset
      ind.search = item$ind.search
      search = search.grid[ind.search,]
      
      args.TFDTW.synth.all.units[["data"]] = data.list[[ind.dataset]]
      results = SimDesign::quiet(
        grid.search(filter.width.range = search$filter.width,
                    k.range = search$k,
                    step.pattern.range = step.pattern.range[search$step.pattern],
                    args.TFDTW.synth.all.units = args.TFDTW.synth.all.units,
                    grid.search.parallel = grid.search.parallel)
      )
      results
    }
  )


## Results ---------------------------------------------------------------------
results = readRDS("./data/results5.Rds")
res = results %>% 
  future_map(
    ~{
      item = .[[1]]
      res.synth = map2(
        item$results.TFDTW.synth,
        names(item$results.TFDTW.synth),
        ~{
          result = .x
          unit = .y
          data.frame(unit = unit,
                     time = 1:100,
                     value = result$res.synth.raw$value,
                     original = result$res.synth.raw$synthetic,
                     TFDTW = result$res.synth.TFDTW$synthetic)
        }
      ) %>% 
        do.call("rbind", .)
      res.synth = res.synth %>% 
        mutate(gap.original = value - original,
               gap.TFDTW = value - TFDTW)
      gap.original = res.synth %>% filter(unit == "A") %>% .["gap.original"]
      gap.TFDTW = res.synth %>% filter(unit == "A") %>% .["gap.TFDTW"]
      res.synth = res.synth %>% 
        filter(unit != "A")
      df.quant = res.synth %>% 
        group_by(time) %>% 
        summarise(
          ci_origin_upper = quantile(gap.original, 0.975, na.rm = T),
          ci_origin_lower = quantile(gap.original, 0.025, na.rm = T),
          ci_new_upper = quantile(gap.TFDTW, 0.975, na.rm = T),
          ci_new_lower = quantile(gap.TFDTW, 0.025, na.rm = T)
        )
      df.quant$gap.original = gap.original
      df.quant$gap.TFDTW = gap.TFDTW
      df.quant$gap.original.zero = gap.original - causal_effect
      df.quant$gap.TFDTW.zero = gap.TFDTW - causal_effect
      df.quant = df.quant %>% 
        mutate(sig.original = ifelse(gap.original > ci_origin_upper | gap.original < ci_origin_lower, 1, 0),
               sig.TFDTW = ifelse(gap.TFDTW > ci_new_upper | gap.TFDTW < ci_new_lower, 1, 0),
               # sig.TFDTW = ifelse(gap.TFDTW > ci_origin_upper | gap.original < ci_origin_lower, 1, 0),
               sig.original.zero = ifelse(gap.original.zero > ci_origin_upper | gap.original.zero < ci_origin_lower, 1, 0),
               sig.TFDTW.zero = ifelse(gap.TFDTW.zero > ci_new_upper | gap.TFDTW.zero < ci_new_lower, 1, 0),
               # sig.TFDTW.zero = ifelse(gap.TFDTW.zero > ci_origin_upper | gap.TFDTW.zero < ci_origin_lower, 1, 0)
               ) %>% 
        data.frame(.) %>% 
        `rownames<-`(1:100)
      df.quant
    }
  ) %>% 
  do.call("rbind", .)

res = res %>% filter(time > 60 & time < 71)
res = res[, -(1:9)]
res = res[complete.cases(res),]

res.boot = NULL
for (i in 1:100) {
  ind = sample(1:nrow(res), 1000, replace = TRUE)
  boot = res[ind,]
  res.boot = rbind(res.boot, colMeans(boot, na.rm = TRUE))
}
boxplot(res.boot[,1:2])

log.ratio = log(res.boot[, 2]/res.boot[, 1])
t.test(log.ratio)


## Pooled Results --------------------------------------------------------------
results = readRDS("./data/results5.Rds")

res = future_map2(
  results,
  as.list(1:99),
  ~{
    item = .x[[1]]
    id = .y
    res.synth = map2(
      item$results.TFDTW.synth,
      names(item$results.TFDTW.synth),
      ~{
        result = .x
        unit = .y
        data.frame(data.id = id,
                   unit = unit,
                   time = 1:100,
                   value = result$res.synth.raw$value,
                   original = result$res.synth.raw$synthetic,
                   TFDTW = result$res.synth.TFDTW$synthetic)
      }
    ) %>% 
      do.call("rbind", .)
    res.synth = res.synth %>% 
      mutate(gap.original = value - original,
             gap.TFDTW = value - TFDTW)
    res.synth
  }
) %>% do.call("rbind", .)


target.df = res %>% filter(unit == "A")
df.quant = res %>%
  filter(unit != "A") %>% 
  group_by(time) %>% 
  summarise(
    ci_origin_upper = quantile(gap.original, 0.975, na.rm = T),
    ci_origin_lower = quantile(gap.original, 0.025, na.rm = T),
    ci_new_upper = quantile(gap.TFDTW, 0.975, na.rm = T),
    ci_new_lower = quantile(gap.TFDTW, 0.025, na.rm = T)
  )

target.df$ci_origin_upper = rep(df.quant$ci_origin_upper, 99)
target.df$ci_origin_lower = rep(df.quant$ci_origin_lower, 99)
target.df$ci_new_upper = rep(df.quant$ci_new_upper, 99)
target.df$ci_new_lower = rep(df.quant$ci_new_lower, 99)

target.df = target.df %>% 
  mutate(sig.original = ifelse(gap.original > ci_origin_upper | gap.original < ci_origin_lower, 1, 0),
         sig.TFDTW = ifelse(gap.TFDTW > ci_new_upper | gap.TFDTW < ci_new_lower, 1, 0)
  )

res.sig = target.df %>% 
  filter(time > 60 & time < 71)

mean(res.sig$sig.original, na.rm = TRUE)
mean(res.sig$sig.TFDTW, na.rm = TRUE)



