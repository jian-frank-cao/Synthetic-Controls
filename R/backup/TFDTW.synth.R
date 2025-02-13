TFDTW.synth = function(data, start.time, end.time, treat.time,
                       dependent, dependent.id,
                       args.TFDTW, args.synth,
                       pred.vars = NULL,
                       res.synth.raw = NULL,
                       n.mse = 10, plot.figures = FALSE,
                       plot.path = "./figures/",
                       legend.pos = c(0.3, 0.3)){
  # prepare data for TFDTW
  t.treat = (treat.time - start.time) + 1
  
  y.raw = data %>% 
    filter(unit == dependent & time <= end.time) %>%
    .[["value_raw"]]
  
  y.processed = data %>% 
    filter(unit == dependent & time <= end.time) %>%
    .[["value"]]
  
  x.list = data %>% 
    filter(unit != dependent & time <= end.time) %>% 
    # select(c("unit", "time", "value", "value_raw")) %>%
    group_by(unit) %>% 
    group_split(.keep = TRUE)
  
  args.TFDTW[["y"]] = y.processed
  args.TFDTW[["t.treat"]] = t.treat
  args.TFDTW[["plot.figures"]] = plot.figures
  
  # TFDTW
  results = NULL
  for (item in x.list) {
    unit = as.character(item$unit[1])
    x.raw = item$value_raw
    args.TFDTW[["x"]] = item$value
    
    res = do.call(TFDTW, args.TFDTW)
    
    x.warped = c(
      warpWITHweight(x.raw[1:res$cutoff], res$weight.a)[1:t.treat],
      warpWITHweight(x.raw[res$cutoff:length(x.raw)], res$avg.weight)[-1]
    )
    
    item$value_warped = x.warped[1:length(y.raw)]
    
    if (!is.null(pred.vars)) {
      for (pred.var in pred.vars) {
        pred.target = item[[pred.var]]
        pred.target.warped = c(
          warpWITHweight(pred.target[1:res$cutoff], res$weight.a)[1:t.treat],
          warpWITHweight(pred.target[res$cutoff:length(pred.target)],
                         res$avg.weight)[-1]
        )
        item[[pred.var]] = pred.target.warped[1:length(y.raw)]
      }
    }
    
    df.synth = item %>% 
      mutate(time = 1:length(y.raw) + start.time - 1,
             unit = unit)
    
    fig.warp = NULL
    if (plot.figures) {
      fig.warp = plot.warped(unit = unit, dependent = dependent,
                             t.treat = t.treat, y.raw = y.raw,
                             x.raw = x.raw, x.warped = x.warped,
                             legend.pos = legend.pos)
    }
    
    results[[unit]] = list(unit = unit, 
                           x.warped = x.warped,
                           df.synth = df.synth,
                           fig.warp = fig.warp)
  }
  
  # plot warped data
  if (plot.figures) {
    file.name = paste0(plot.path, "warped-", dependent, ".pdf")
    stack.warped(fig.list = lapply(results,"[[","fig.warp"),
                 file.name = file.name, ncol = 3)
  }
  
  # prepare data for Synth
  df.synth = lapply(results, "[[", "df.synth") %>% 
    do.call("rbind", .) %>% 
    `row.names<-`(NULL)
  
  df.dependent = data %>% 
    filter(unit == dependent & time <= end.time) %>% 
    mutate(time = 1:length(y.raw) + start.time - 1,
           unit = dependent,
           value_warped = y.raw)
  df.synth = rbind(df.synth, df.dependent)
  df.synth = data.frame(df.synth)
  
  args.synth[["df"]] = df.synth
  args.synth[["dependent.id"]] = dependent.id
  
  # Synth
  if (is.null(res.synth.raw)) {
    args.synth[["dep.var"]] = "value_raw"
    res.synth.raw = do.call(do.synth, args.synth)
  }
  
  args.synth[["dep.var"]] = "value_warped"
  res.synth.TFDTW = do.call(do.synth, args.synth)
  
  # plot synthetic control
  if (plot.figures) {
    file.name = paste0(plot.path, "synth_", dependent, ".pdf")
    plot.synth(res.synth.raw = res.synth.raw,
               res.synth.TFDTW = res.synth.TFDTW,
               dependent = dependent, start.time = start.time,
               end.time = end.time, treat.time = treat.time,
               file.name = file.name, legend.pos = legend.pos)
  }
  
  # output
  gap.raw = res.synth.raw$value - res.synth.raw$synthetic
  gap.TFDTW = res.synth.TFDTW$value - res.synth.TFDTW$synthetic
  
  mse = data.frame(
    unit = dependent,
    mse.preT.raw = mean(gap.raw[1:(t.treat-1)]^2, na.rm = T),
    mse.preT.TFDTW = mean(gap.TFDTW[1:(t.treat-1)]^2, na.rm = T),
    mse.postT.raw = mean(gap.raw[(t.treat+1):(t.treat+n.mse)]^2, na.rm = T),
    mse.postT.TFDTW = mean(gap.TFDTW[(t.treat+1):(t.treat+n.mse)]^2, na.rm = T)
  )
  
  return(list(dependent = dependent, dependent.id = dependent.id,
              # args.TFDTW = args.TFDTW, args.synth = args.synth,
              # results.TFDTW = results, df.synth = df.synth,
              res.synth.raw = res.synth.raw,
              res.synth.TFDTW = res.synth.TFDTW,
              gap.raw = gap.raw, gap.TFDTW = gap.TFDTW,
              mse = mse))
}