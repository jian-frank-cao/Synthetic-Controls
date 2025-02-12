for (i in (1:10)*2+3) {
  for (j in 2:6) {
    for (z in 1:5) {
      if (z > j | i <= j) {
        next
      }
      gdp = reshape2::dcast(data %>% select(c("country", "year", "gdp")), year ~ country, value.var = "gdp")
      # row.names(gdp) = gdp$year
      # gdp = gdp %>% select(-c("Norway", "Portugal"))
      
      ## minmax
      # gdp = gdp %>% mutate_at(setdiff(colnames(gdp), "year"), ~normalize(., "minmax"))
      
      ## t
      gdp = gdp %>% mutate_at(setdiff(colnames(gdp), "year"), ~normalize(., "t"))
      
      ## adding buffer
      add_buffer = function(TS, n){
        model_right = forecast::auto.arima(TS)
        right <- as.numeric(forecast::forecast(model_right, h = n)$mean)
        model_left = forecast::auto.arima(rev(TS))
        left <- rev(as.numeric(forecast::forecast(model_left, h = n)$mean))
        
        return(c(left, TS, right))
      }
      
      width = i
      gdp_b = sapply(gdp %>% select(-year), add_buffer, n = (width - 1)/2) %>% 
        data.frame(.)
      
      ## derivative
      gdp_b = gdp_b %>%
        mutate_all(~signal::sgolayfilt(., j, width, z)) %>%
        .[((width - 1)/2 + 1):((width - 1)/2 + nrow(gdp)),]
      gdp[-1] = gdp_b
      
      res = mean(mean(var(gdp_b)))
      
      print(paste0(c(i, j, z, res), collapse = "-"))
    }
  }
}

gdp = reshape2::dcast(data %>% select(c("country", "year", "gdp")), year ~ country, value.var = "gdp")
# row.names(gdp) = gdp$year
# gdp = gdp %>% select(-c("Norway", "Portugal"))

## minmax
# gdp = gdp %>% mutate_at(setdiff(colnames(gdp), "year"), ~normalize(., "minmax"))

## t
gdp = gdp %>% mutate_at(setdiff(colnames(gdp), "year"), ~normalize(., "t"))

## adding buffer
add_buffer = function(TS, n){
  model_right = forecast::auto.arima(TS)
  right <- as.numeric(forecast::forecast(model_right, h = n)$mean)
  model_left = forecast::auto.arima(rev(TS))
  left <- rev(as.numeric(forecast::forecast(model_left, h = n)$mean))
  
  return(c(left, TS, right))
}

width = 9
gdp_b = sapply(gdp %>% select(-year), add_buffer, n = (width - 1)/2) %>% 
  data.frame(.)

## derivative
gdp_b = gdp_b %>%
  mutate_all(~signal::sgolayfilt(., 3, width, 2)) %>%
  .[((width - 1)/2 + 1):((width - 1)/2 + nrow(gdp)),]
gdp[-1] = gdp_b

## detrend
# library(remotes)
# remotes::install_github("jrevenaugh/TSAUMN")
# gdp = gdp %>% mutate_at(setdiff(colnames(gdp), "year"), ~TSAUMN::detrend(., 3))


df <- reshape2::melt(gdp ,  id.vars = 'year', variable.name = 'country')


# df = df %>% filter(!(country %in% c("Portugal", "New Zealand", "Norway", "West Germany",
#                                     "UK", "USA")))
# plot on same grid, each series colored differently -- 
# good if the series have same scale
ggplot(df, aes(year,value)) + geom_line(aes(colour = country))

# ------------------------------------------------------------------------------
data = smoking
ggplot(data, aes(time,value)) + geom_line(aes(colour = as.factor(unit)))

values = reshape2::dcast(data %>% select(c("unit", "time", "value")), time ~ unit, value.var = "value")

## minmax
# values = values %>% mutate_at(setdiff(colnames(values), "time"), ~normalize(., "minmax"))

## t
values = values %>% mutate_at(setdiff(colnames(values), "time"), ~normalize(., "t"))

## adding buffer
add_buffer = function(TS, n){
  model_right = forecast::auto.arima(TS)
  right <- as.numeric(forecast::forecast(model_right, h = n)$mean)
  model_left = forecast::auto.arima(rev(TS))
  left <- rev(as.numeric(forecast::forecast(model_left, h = n)$mean))
  
  return(c(left, TS, right))
}

width = 21
values2 = sapply(values %>% select(-time), add_buffer, n = (width - 1)/2) %>% 
  data.frame(.)

## derivative
values2 = values2 %>%
  mutate_all(~signal::sgolayfilt(., 3, width, 2)) %>%
  .[((width - 1)/2 + 1):((width - 1)/2 + nrow(values)),]
values[-1] = values2

# plot
df <- reshape2::melt(values ,  id.vars = 'time', variable.name = 'unit')
# df = df %>% filter(!(country %in% c("Portugal", "New Zealand", "Norway", "West Germany",
ggplot(df, aes(time,value)) + geom_line(aes(colour = unit))


## grid search -----------------------------------------------------------------
res_grid = NULL
for (width in (2:6)*2+3) {
  for (k in 4:7) {
    for (dtw1_time in 1985:1992) {
      ## Data ------------------------------------------------------------------------
      load("./data/smoking.rda")
      prop99 = read.csv("./data/prop99.csv")
      
      exclude_states = c("Massachusetts", "Arizona", "Oregon", "Florida",
                         "Alaska", "Hawaii", "Maryland", "Michigan",
                         "New Jersey", "New York",
                         "Washington", "District of Columbia")
      states = data.frame(id = 1:39,
                          state = sort(setdiff(unique(prop99$LocationDesc),
                                               exclude_states)))
      smoking = smoking %>% mutate_all(as.numeric)
      colnames(smoking)[1] = "id"
      smoking = right_join(states, smoking, by = "id")
      colnames(smoking)[2:4] = c("unit", "time", "value")
      smoking = smoking %>% mutate(value_raw = value)
      
      ## Pre-processing --------------------------------------------------------------
      values = reshape2::dcast(smoking %>% select(c("unit", "time", "value_raw")),
                               time ~ unit, value.var = "value_raw")
      
      # transform
      values = values %>% mutate_at(setdiff(colnames(values), "time"),
                                    ~normalize(., "t"))
      
      # adding buffer
      add_buffer = function(TS, n){
        model_right = forecast::auto.arima(TS)
        right <- as.numeric(forecast::forecast(model_right, h = n)$mean)
        model_left = forecast::auto.arima(rev(TS))
        left <- rev(as.numeric(forecast::forecast(model_left, h = n)$mean))
        
        return(c(left, TS, right))
      }
      
      values2 = sapply(values %>% select(-time),
                       add_buffer, n = (width - 1)/2) %>% 
        data.frame(.)
      
      # derivative
      values2 = values2 %>%
        mutate_all(~signal::sgolayfilt(., 3, width, 2)) %>%
        .[((width - 1)/2 + 1):((width - 1)/2 + nrow(values)),]
      values[-1] = values2
      
      # join data 
      df <- reshape2::melt(values ,  id.vars = 'time',
                           variable.name = 'unit')
      
      smoking = right_join(df, smoking %>% select(-value), by = c("time", "unit"))
      smoking$age15to24 = smoking$age15to24*100
      smoking = smoking[c("id", "unit", "time", "value", 
                          "lnincome", "beer", "age15to24",
                          "retprice", "value_raw")]
      
      ## run
      print(paste0(paste0(c(width, k, dtw1_time), collapse = "-"), "...start..."))
      units = smoking[c("id", "unit")] %>% distinct
      result = as.list(1:39) %>% 
        future_map(
          ~{
            i = .
            dependent = units$unit[i]
            dependent_id = units$id[i]
            print(paste0(dependent, ":", i, "-", k, " start..."))
            res = compare_methods(data = smoking,
                                  start_time = 1970,
                                  end_time = 1995,
                                  treat_time = 1985,
                                  dtw1_time = dtw1_time,
                                  dependent = dependent,
                                  dependent_id = dependent_id,
                                  normalize_method = "t",
                                  k = k,
                                  step.pattern = dtw::symmetricP2)
            print(paste0(dependent, ":", i, "-", k, " start...Done."))
            res$mse %>% mutate(dependent = dependent, k = k)
          }
        )
      
      result = result %>% 
        do.call("rbind", .) %>% 
        mutate(ratio = (mse1_post - mse2_post)/mse1_post)
      res = data.frame(width = width,
                       k = k,
                       dtw1_time = dtw1_time,
                       ratio = length(which(result$ratio>0))/39)
      res_grid = rbind(res_grid, res)
    }
  }
}
          
res_grid = NULL      
for (width in (1:6)*2+3) {
  for (k in 4:7) {
    for (dtw1_time in 1987:1994) {
      temp = data.frame(width = width,
                        k = k,
                        dtw1_time = dtw1_time,
                        ratio = NA_real_)
      res_grid = rbind(res_grid, temp)
    }
  }
}

# res_grid = left_join(res_grid[,-4], res_grid2, by = c("width", "k", "dtw1_time"))

grid_search = function(width, k, dtw1_time){
  ## Data ------------------------------------------------------------------------
  smoking = readRDS("./data/data_smoking.Rds")
  
  ## Pre-processing --------------------------------------------------------------
  values = reshape2::dcast(smoking %>% select(c("unit", "time", "value_raw")),
                           time ~ unit, value.var = "value_raw")
  
  # transform
  values = values %>% mutate_at(setdiff(colnames(values), "time"),
                                ~normalize(., "t"))
  
  # adding buffer
  add_buffer = function(TS, n){
    model_right = forecast::auto.arima(TS)
    right <- as.numeric(forecast::forecast(model_right, h = n)$mean)
    model_left = forecast::auto.arima(rev(TS))
    left <- rev(as.numeric(forecast::forecast(model_left, h = n)$mean))
    
    return(c(left, TS, right))
  }
  
  values2 = sapply(values %>% select(-time),
                   add_buffer, n = (width - 1)/2) %>% 
    data.frame(.)
  
  # derivative
  values2 = values2 %>%
    mutate_all(~signal::sgolayfilt(., 3, width, 2)) %>%
    .[((width - 1)/2 + 1):((width - 1)/2 + nrow(values)),]
  values[-1] = values2
  
  # join data 
  df <- reshape2::melt(values ,  id.vars = 'time',
                       variable.name = 'unit')
  
  smoking = right_join(df, smoking %>% select(-value), by = c("time", "unit"))
  smoking$age15to24 = smoking$age15to24*100
  smoking = smoking[c("id", "unit", "time", "value", 
                      "lnincome", "beer", "age15to24",
                      "retprice", "value_raw")]
  
  ## run
  print(paste0(paste0(c(width, k, dtw1_time), collapse = "-"), "...start..."))
  units = smoking[c("id", "unit")] %>% distinct
  result = as.list(1:nrow(units)) %>% 
    future_map(
      ~{
        i = .
        dependent = units$unit[i]
        dependent_id = units$id[i]
        print(paste0(dependent, ":", i, "-", k, " start..."))
        res = compare_methods(data = smoking,
                              start_time = 1970,
                              end_time = 1997,
                              treat_time = 1987,
                              dtw1_time = dtw1_time,
                              dependent = dependent,
                              dependent_id = dependent_id,
                              normalize_method = "t",
                              k = k,
                              step.pattern = dtw::symmetricP2)
        print(paste0(dependent, ":", i, "-", k, " start...Done."))
        res$mse %>% mutate(dependent = dependent, k = k)
      }
    )
  
  result = result %>% 
    do.call("rbind", .) %>% 
    mutate(improve = mse1_post - mse2_post)
  
  return(length(which(result$improve > 0))/nrow(result))
}

for (i in which(is.na(res_grid$ratio))) {
  width = res_grid$width[i]
  k = res_grid$k[i]
  dtw1_time = res_grid$dtw1_time[i]
  
  res_grid$ratio[i] = grid_search(width, k, dtw1_time)
  gc()
}

result_1985 = readRDS("./data/result_tobacco_1985.Rds")
result_1987 = readRDS("./data/result_tobacco_1987.Rds")
result_1989 = readRDS("./data/result_tobacco_1989.Rds")
result_1990 = readRDS("./data/result_gdp_1990.Rds")


result = rbind(result_1985 %>% mutate(treatment = "Tobacco_1985"),
               result_1987 %>% mutate(treatment = "Tobacco_1987"),
               result_1989 %>% mutate(treatment = "Tobacco_1989"),
               result_1990 %>% mutate(treatment = "GDP_1990"))

result = result %>% filter(dependent != "Rhode Island")
result = result %>% mutate(ratio = mse2_post/mse1_post,
                           log_ratio = log(ratio))

ggplot(result, aes(x=treatment, y=log_ratio)) + 
  geom_boxplot() +
  theme_bw() +
  # coord_cartesian(ylim = c(-40, 70)) +
  geom_hline(yintercept=0, linetype="dashed")


t_test = result %>% group_by(treatment) %>% 
  summarise(t_test = t.test(log_ratio)$p.value)


# ------------------------------------------------------------------------------
res_grid = NULL      
for (width in (1:6)*2+3) {
  for (k in 4:7) {
    for (dtw1_time in 1990:1997) {
      temp = data.frame(width = width,
                        k = k,
                        dtw1_time = dtw1_time,
                        ratio = NA_real_)
      res_grid = rbind(res_grid, temp)
    }
  }
}


grid_search = function(width, k, dtw1_time){
  ## Data ------------------------------------------------------------------------
  data = foreign::read.dta("./data/repgermany.dta")
  colnames(data)[1:4] = c("id", "unit", "time", "value")
  data = data %>% mutate(value_raw = value)
  
  
  ## Pre-processing --------------------------------------------------------------
  values = reshape2::dcast(data %>% select(c("unit", "time", "value_raw")),
                           time ~ unit, value.var = "value_raw")
  
  # transform
  values = values %>% mutate_at(setdiff(colnames(values), "time"),
                                ~normalize(., "t"))
  
  # adding buffer
  add_buffer = function(TS, n){
    model_right = forecast::auto.arima(TS)
    right <- as.numeric(forecast::forecast(model_right, h = n)$mean)
    model_left = forecast::auto.arima(rev(TS))
    left <- rev(as.numeric(forecast::forecast(model_left, h = n)$mean))
    
    return(c(left, TS, right))
  }
  
  width = width
  values2 = sapply(values %>% select(-time),
                   add_buffer, n = (width - 1)/2) %>% 
    data.frame(.)
  
  # derivative
  values2 = values2 %>%
    mutate_all(~signal::sgolayfilt(., 3, width, 2)) %>%
    .[((width - 1)/2 + 1):((width - 1)/2 + nrow(values)),]
  values[-1] = values2
  
  # join data 
  df <- reshape2::melt(values ,  id.vars = 'time',
                       variable.name = 'unit')
  
  data = right_join(df, data %>% select(-value), by = c("time", "unit"))
  data = data[c("id", "unit", "time", "value", colnames(data)[-(1:4)])]
  
  
  ## run
  print(paste0(paste0(c(width, k, dtw1_time), collapse = "-"), "...start..."))
  units = data[c("id", "unit")] %>% distinct
  result = as.list(1:nrow(units)) %>% 
    future_map(
      ~{
        i = .
        dependent = units$unit[i]
        dependent_id = units$id[i]
        print(paste0(dependent, ":", i, "-", k, " start..."))
        res = compare_methods(data = data,
                              start_time = 1960,
                              end_time = 2003,
                              treat_time = 1990,
                              dtw1_time = dtw1_time,
                              dependent = dependent,
                              dependent_id = dependent_id,
                              normalize_method = "t",
                              k = k,
                              plot_figures = T,
                              step.pattern = dtw::symmetricP2)
        print(paste0(dependent, ":", i, "-", k, " start...Done."))
        res$mse %>% mutate(dependent = dependent, k = k)
      }
    )
  
  result = result %>% 
    do.call("rbind", .) %>% 
    mutate(improve = mse1_post - mse2_post)
  
  return(length(which(result$improve > 0))/nrow(result))
}

for (i in which(is.na(res_grid$ratio))) {
  width = res_grid$width[i]
  k = res_grid$k[i]
  dtw1_time = res_grid$dtw1_time[i]
  
  res_grid$ratio[i] = grid_search(width, k, dtw1_time)
  gc()
}


mratios::ttestratio(result %>% filter(year == "Tobacco_1989") %>% .[["mse2_post"]],
                    result %>% filter(year == "Tobacco_1989") %>% .[["mse1_post"]])

result = result %>% mutate(ratio = mse2_post/mse1_post)
t.test(log(result %>% filter(year == "Tobacco_1985") %>% .[["ratio"]]))
t.test(log(result %>% filter(year == "Tobacco_1987") %>% .[["ratio"]]))
t.test(log(result %>% filter(year == "Tobacco_1989") %>% .[["ratio"]]))

t.test(log(result_1985$mse2_post)-log(result_1985$mse1_post))
t.test(log(result_1987$mse2_post)-log(result_1987$mse1_post))
t.test(log(result_1989$mse2_post)-log(result_1989$mse1_post))
t.test(log(result_1990$mse2_post)-log(result_1990$mse1_post))



