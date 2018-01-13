
########### data structure

# results <- tibble(
#   model = character(),
#   dataset = character(),
#   pooling = character(),
#   package = character(),
#   method = character(),
#   est_group = list(tibble()),
#   est_indiv = list(tibble()),
#   test_between = list(tibble()),
#   #est_cov = est_cov,
#   gof = list(tibble()),
#   gof_group = list(tibble()),
#   gof_indiv = list(tibble())
# )

make_results_row <- function(model, dataset, pooling, package, method,
                             data, parameters, 
                             col_id = "id", col_condition = "condition") {
  
  # prepare data to have the correct columns of id/condition
  data$id <- data[[col_id]]
  data$condition <- data[[col_condition]]
  conditions <- levels(factor(data$condition))
  parameters <- check.mpt(model)$parameters

  est_ind <-
    as_tibble(expand.grid(parameter = parameters,
                          id = data$id))
  est_ind <- left_join(est_ind, data[, c("id", "condition")], by = "id")
  est_ind <- est_ind[,c("id", "condition", "parameter")]
  est_ind <- add_column(est_ind, est = NA_real_, se = NA_real_)
  for (i in seq_along(CI_SIZE)) {
    est_ind <- add_column(est_ind, xx = NA_real_)
    colnames(est_ind)[ncol(est_ind)] <- paste0("ci_", CI_SIZE[i])
  }
  
  
  # create est_group empty df
  est_group <- as_tibble(expand.grid(parameter = parameters,
                                     condition = levels(data$condition)))
  est_group <- est_group[,c("condition", "parameter")]
  est_group <- as_tibble(data.frame(est_group,
                                    est = NA_real_,
                                    se = NA_real_))
  for (i in seq_along(CI_SIZE)) {
    est_group <- add_column(est_group, xx = NA_real_)
    colnames(est_group)[ncol(est_group)] <- paste0("ci_", CI_SIZE[i])
  }
  
  
  # group comparisons
  if (length(conditions) > 1) {
      pairs <- combn(conditions, 2)
      test_between <- 
        as_tibble(expand.grid(parameter = parameters, 
                              condition1 = factor(pairs[1,], levels = conditions),
                              condition2 = factor(pairs[2,], levels = conditions))) %>% 
        mutate(est_diff = NA_real_, se = NA_real_, p = NA_real_)
      tibble_ci <- as_tibble(matrix(NA_real_, nrow(test_between), length(CI_SIZE),
                                    dimnames = list(NULL, paste0("ci_", CI_SIZE))))
      test_between <- bind_cols(test_between, tibble_ci)
  } else {
    test_between <- tibble()
  }

  
  
  ## est_covariate <- ##MISSING
  
  ## create gof empty df
  gof <- tibble(
    type = "",
    focus = "",
    stat_obs = NA_real_,
    stat_pred = NA_real_,
    stat_df = NA_real_,
    p = NA_real_
  )
  
  ## create gof_group empty df
  gof_group <- as_tibble(data.frame(condition = levels(data$condition),
                                    gof))
  ## create gof_groupindiv empty df
  gof_indiv <- as_tibble(data.frame(data[,c("id", "condition")], gof))
  
  tibble(
    model = model,
    dataset = dataset,
    pooling = pooling,
    package = package,
    method = method,
    est_group = list(est_group),
    est_indiv = list(est_ind),
    test_between = list(test_between),
    #est_cov = est_cov,
    gof = list(gof),
    gof_group = list(gof_group),
    gof_indiv = list(gof_indiv),
    convergence = list(tibble())
  )
}

prep_data_fitting <- function(data, # data.frame 
                              model_file, 
                              col_id, 
                              col_condition) {
  if (!is.factor(data[[col_condition]])) {
    stop(col_condition, " (condition column) needs to be a factor!", 
         call. = FALSE)
  }
  
  data$id <- data[,col_id]
  data$condition <- data[,col_condition]
  col_freq <- get_eqn_categories(model_file)
  
  out <- list(
    conditions = levels(data[[col_condition]]),
    parameters = check.mpt(model_file)$parameters,
    col_freq = col_freq,
    freq_list = split(data[,col_freq], f = data[,col_condition]),
    cols_ci = paste0("ci_", CI_SIZE),
    data = data
  )
}

get_eqn_categories <- function (model.filename)
{
  parse.eqn <- function(x) {
    branches <- unique(x[, 2])
    l.tree <- length(branches)
    tree <- vector("expression", l.tree)
    for (branch in 1:l.tree) {
      tree[branch] <- parse(text = paste(x[x$V2 == branches[branch],
                                           "V3"], collapse = " + "))
    }
    tree
  }
  #browser()
  tmp.in <- read.table(model.filename, skip = 1, stringsAsFactors = FALSE)
  tmp.ordered <- tmp.in[order(tmp.in$V1), ]
  tmp.spl <- split(tmp.ordered, factor(tmp.ordered$V1))
  tmp.spl <- lapply(tmp.spl, function(d.f) d.f[order(d.f[,
                                                         2]), ])
  unlist(lapply(tmp.spl, function(x) unique(x$V2)))
  # model <- lapply(tmp.spl, parse.eqn)
  # names(model) <- NULL
  # model
}