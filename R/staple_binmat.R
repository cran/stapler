#' STAPLE on binary matrix
#'
#' @param x a nxr matrix where there are n raters and r elements rated
#' @param sens_init Initialize parameter for sensitivity (p)
#' @param spec_init  Initialize parameter for specificity (q)
#' @param max_iter Maximum number of iterations to run
#' @param tol Tolerance for convergence
#' @param prior Either "mean" or a vector of prior probabilities,
#' @param verbose print diagnostic messages
#' @param trace Number for modulus to print out verbose iterations
#' @param drop_all_same drop all records where they are all the same.
#' DO NOT use in practice, only for validation of past results
#'
#' @return List of output sensitivities, specificities, and
#' vector of probabilities
#' @export
#'
#' @examples
#' n = 5
#' r = 1000
#' sens = c(0.8, 0.9, 0.8, 0.5, 0.8)
#' spec = c(0.9, 0.75, 0.99, 0.98, 0.92)
#' suppressWarnings(RNGversion("3.5.0"))
#' set.seed(20171120)
#' n_1 = 200
#' n_0 = r - n_1
#' truth = c(rep(0, n_0), rep(1, n_1))
#' pred_1 = rbinom(n = n, size = n_1, prob = sens)
#' pred_0 = rbinom(n = n, size = n_0, prob = spec)
#' pred_0 = sapply(pred_0, function(n) {
#'    sample(c(rep(0, n), rep(1, n_0 -n)))
#' })
#' pred_1 = sapply(pred_1, function(n) {
#'    sample(c(rep(1, n), rep(0, n_1 -n)))
#' })
#' pred = rbind(pred_0, pred_1)
#' true_sens = colMeans(pred[ truth == 1, ])
#' true_spec = colMeans(1-pred[ truth == 0, ])
#' x = t(pred)
#' staple_out = staple_bin_mat(x)
#' testthat::expect_equal(staple_out$sensitivity,
#' c(0.781593858553476, 0.895868301462594,
#' 0.760514086161722, 0.464483444340873,
#' 0.765239314719065))
#' staple_out_prior = staple_bin_mat(x, prior = rep(0.5, r))
#' testthat::expect_equal(staple_out_prior$sensitivity,
#' c(0.683572080864211, 0.821556768891859,
#' 0.619166852992802, 0.389409921992467, 0.67042085955546))
#'
#' @importFrom matrixStats colProds
staple_bin_mat = function(
  x,
  sens_init = 0.99999,
  spec_init = 0.99999,
  max_iter = 10000,
  tol = .Machine$double.eps,
  prior = "mean",
  verbose = TRUE,
  trace = 10,
  drop_all_same = FALSE
) {
  n_readers = nrow(x)
  n_all_voxels = ncol(x)

  if (n_readers > n_all_voxels) {
    warning(paste0(
      "Number of readers larger than number of elements.",
      "Are you sure matrix x is nxr?")
    )
  }

  stopifnot(!any(is.na(x)))
  umat = sort(unique(c(x)))
  umat = as.numeric(umat)
  if (!all(umat %in% c(0, 1))) {
    warning(paste0("Staple expecting binary matrix ",
                   "- some elements not in {0, 1}"))
  }
  x = x > 0

  cprod = matrixStats::colProds
  # cprod = function(x) {
  #   apply(x, 2, prod)
  # }
  # cprod = function(x) {
  #   stopifnot(all(x > 0))
  #   exp(colSums(log(x)))
  # }

  if (drop_all_same) {
    warning("Dropping values where all the same - may be wrong!")
    cs = colSums(x)
    all_zero = cs == 0
    # only_one = cs == 1
    # if all vote yes - then yes
    all_one = cs == n_readers
    keep = !all_zero & !all_one
    stopifnot(!anyNA(keep))
  }



  ####################################
  # Keeping only voxels with more than 1 says yes
  ####################################
  # prior = match.arg(prior)
  p1 = prior[1]
  if (p1 == "mean") {
    f_t_i = colMeans(x, na.rm = TRUE)
    prior = f_t_i
  } else {
    prior = as.vector(prior)
    n_prior = length(prior)
    if (n_prior != n_all_voxels) {
      stop("Prior does not have same number of rated elements!")
    }
    stopifnot(!any(is.na(prior)))
    f_t_i = prior
    if (any(prior %in% c(0, 1))) {
      warning("Some elements in prior are in {0, 1}")
    }
    if (drop_all_same) {
      all_one = all_one | prior == 1
      all_zero = all_zero | prior == 0
      keep = !all_zero & !all_one
      stopifnot(!any(is.na(keep)))
    }
  }
  if (!drop_all_same) {
    keep = rep(TRUE, n_all_voxels)
  }

  mat = x[, keep]
  f_t_i = f_t_i[keep]

  rm(x)

  # if (any(f_t_i %in% c(0, 1))) {
  #   warning("Some elements in prior are in {0, 1}")
  # }

  n_voxels = ncol(mat)
  # dmat = (1L - mat) > 0
  dmat = !mat

  d_f_t_i = 1 - f_t_i

  # doing this for na.rm arguments
  # tied to first code
  # mat[ mat == 0] = NA
  # dmat[dmat == 0] = NA

  ###################
  #initialize
  p = rep(sens_init, n_readers)
  q = rep(spec_init, n_readers)


  eps = sqrt(tol)

  # mat is D
  ### run E Step
  for (iiter in seq(max_iter)) {
    # pmat = p * mat
    # pmat = cprod(pmat, na.rm = TRUE)
    # sep_pmat = (1 - p) * dmat
    # sep_pmat =  cprod(sep_pmat, na.rm = TRUE)
    #
    # qmat = q * mat
    # qmat =  cprod(qmat, na.rm = TRUE)
    # sep_qmat = (1 - q) * dmat
    # sep_qmat =  cprod(sep_qmat, na.rm = TRUE)
    # a_i = f_t_i * pmat * sep_pmat
    # b_i = (1 - f_t_i) * qmat * sep_qmat

    # E Step
    # what happens if p or q = 1 or 0?
    # this fails then
    # a_i = p ^ mat * (1 - p) ^ dmat
    test_run = TRUE
    if (test_run) {
      a_i = b_i = mat
      for (ireader in seq_along(p)) {
        # take row for reader j
        # for those elements where D = 1, put p, D = 0, 1-p
        x = a_i[ireader, ]
        x[mat[ireader, ]] = p[ireader]
        x[!mat[ireader, ]] = (1 - p[ireader])
        a_i[ireader, ] = x

        x = b_i[ireader, ]
        x[!mat[ireader, ]] = q[ireader]
        x[mat[ireader, ]] = (1 - q[ireader])
        b_i[ireader, ] = x
      }
      a_i = f_t_i   * cprod(a_i)
      b_i = d_f_t_i * cprod(b_i)

    } else {
      a_i = p ^ mat * (1 - p) ^ dmat
      a_i = f_t_i * cprod(a_i)


      b_i = q ^ dmat * (1 - q) ^ mat
      b_i = d_f_t_i * cprod(b_i)
    }
    W_i = a_i/(a_i + b_i)

    rm(a_i)
    rm(b_i)
    # M step
    ##########################
    # do these make sense to do?
    ##########################
    # W_i = pmin(W_i, 1 - eps)
    # W_i = pmax(W_i, eps)

    sum_w = sum(W_i)

    # works if mat has NA or NOT
    new_p  = t(mat) * W_i
    # new_p  = colSums(new_p,	na.rm = TRUE)
    new_p  = colSums(new_p)
    new_p = new_p/(sum_w + eps)

    new_q  = t(dmat) * (1 - W_i)
    # new_q  = colSums(new_q,	na.rm = TRUE)
    new_q  = colSums(new_q)
    new_q = new_q/(n_voxels - sum_w + eps)


    diff_p = abs(p - new_p)
    diff_q = abs(q - new_q)
    diff = max(c(diff_p, diff_q))
    if (diff <= tol) {
      if (verbose) {
        message("Convergence!")
      }
      break
    } else {
      if (verbose) {
        if (iiter %% trace == 0 || iiter == 1) {
          message(paste0("iter: ", iiter,
                         ", diff: ", diff))
        }
      }
    }

    p = new_p
    q = new_q
  }

  rm(mat)
  rm(dmat)

  if (diff > tol) {
    warning(paste0(
      "Algorithm did not converge - ",
      "may need additional iterations!")
    )
  }
  stopifnot(!any(is.na(W_i)))

  outimg = rep(0, n_all_voxels)
  if (drop_all_same) {
    outimg[ all_one ] = 1
  }
  outimg[keep] = W_i

  L = list(
    sensitivity = p,
    specificity = q,
    probability = outimg,
    label = outimg >= 0.5,
    prior = prior,
    number_iterations = iiter,
    convergence_threshold = tol,
    convergence_value = diff,
    converged = diff <= tol
  )
  return(L)
}
