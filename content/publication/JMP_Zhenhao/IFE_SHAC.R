rm(list = ls())
set.seed(11111)

# packages
library(parallel)
library(foreach)
library(doParallel)

# Form the cluster 
numCores <- detectCores()
numCores
registerDoParallel(numCores)

r <-  2  # number of factors

# True values of the coefficients
beta_1 <- 1


# Function for interactive estimators
# Bai 2009
IFE.new <- function(Y, X, r){
  
  T <- nrow(Y)
  N <- ncol(Y)
  
  Beta_temp <- matrix(1,2,1)
  Beta_temp[2,] <- 1.1
  
  while (abs(Beta_temp[2,] - Beta_temp[1,]) > 10^(-6)) {
    
    Beta_temp[1,] = Beta_temp[2,]
    R_bar = Y - X*Beta_temp[1,]
    
    Eigen <- eigen(R_bar%*%t(R_bar)/(N*T))
    F_temp <- sqrt(T)*Eigen$vectors[, 1:r]
    Lamda_temp <-  (1/T)*t(R_bar)%*%F_temp
    
    P_temp <- F_temp%*%t(F_temp)/T
    M_temp <- diag(1,T,T) - P_temp
    A1 <- sum(diag(t(X)%*%M_temp%*%X))
    A2 <- sum(diag(t(X)%*%M_temp%*%Y))
    
    Beta_temp[2,] = solve(A1)*A2
  }
  return(list(beta = Beta_temp[2,], F_temp = F_temp))
}

# WPC  Bai and Liao (2012)
IFE.WPC <- function(Y, X, Sigu, r){
  
  T <- nrow(Y)
  N <- ncol(Y)
  
  Beta_temp <- matrix(1,2,1)
  Beta_temp[2,] <- 1.1
  
  # M2=0
  # for (t in 1:T) {
  #   M2 <- M2 + X[t,]%*%solve(Sigu)%*%X[t,]
  # }
  
  M2 <- sum(diag(X%*%solve(Sigu)%*%t(X)))
  
  while (abs(Beta_temp[2,] - Beta_temp[1,]) > 10^(-4)) {
    
    Beta_temp[1,] = Beta_temp[2,]
    R_bar = Y - X*Beta_temp[1,]
    
    Eigen <- eigen(R_bar%*%solve(Sigu)%*%t(R_bar)/(N*T))
    F_temp <- sqrt(T)*Eigen$vectors[, 1:r]
    Lamda_temp <-  (1/T)*t(R_bar)%*%F_temp
    
    # G =0
    # for (t in 1:T) {
    #   G = G + X[t,]%*%solve(Sigu)%*%(Y[t,] - Lamda_temp%*%F_temp[t,])
    # }
    
    G <- sum(diag(X%*%solve(Sigu)%*%t(Y - F_temp%*%t(Lamda_temp))))
    
    Beta_temp[2,] = solve(M2)*G
  }
  return(list(beta = Beta_temp[2,], F_temp = F_temp))
}

# return thresholded matrix
# u: N by T
# C: threshold constant, threshold correlation matrix, soft-threshold
Matrix_fun <- function(u, C){
  
  T <- nrow(u)
  N <- ncol(u)
  rate <- 1/sqrt(N)+sqrt(log(N))/sqrt(T);
  Su=t(u)%*%u/(T-4);
  
  if(N > T*0.3){
    SuDiag <- diag(diag(Su))
    SuDiagHalf <- SuDiag^(1/2)
    R = solve(SuDiagHalf)%*%(Su%*%solve(SuDiagHalf))
    th <- abs(C)*rate
    Rthresh <- matrix(NA, N, N)
    
    for (i in 1:N) {
      for (j in 1:i) {
        if (abs(R[i,j]) < th && j<i){
          Rthresh[i,j] <- 0
        } else if (j==i){
          Rthresh[i,j] = R[i,j] 
        } else{
          Rthresh[i,j] <- sign(R[i,j])*(abs(R[i,j])-th)
        }
        Rthresh[j,i] = Rthresh[i,j]
      }
    }
    Sigma <- SuDiagHalf%*%Rthresh%*%SuDiagHalf
  } else {
    Sigma=Su
  }
}

# optimal bandwidth selection function for SHAC estimators
Bandwidth_opt <- function(N, T, spatial, rho, S, B){
  
  # Construct the Bias term using spatial HAC
  # Distance out of whose value is 0 in W
  h= sqrt(N)
  D <- matrix(0, N, N)
  D1 <- repmat(matrix(1:h,h,1), h, 1)
  D2 <- kron(matrix(1:h,h,1), rep(1,h))
  
  for (i in 1:N) {
    D[i,] = sqrt((D1[i,1]-D1)^2+(D2[i,1]-D2)^2)
  }
  
  ## Weighting matrix
  W1 = 1*(D == 1);
  W2 = 1*(D == sqrt(2))
  
  # Generate loadings
  L  <- matrix(rnorm(N*r,0,1), N, r)
  F  <- matrix(NA, T, r)
  
  # Generate cross-sectional errors and factors
  err_2 <- matrix(NA, T, N)
  err_2[1,] <-  (diag(1, N, N) + spatial*W1 + spatial^2*W2)%*%matrix(rnorm(N,0,1), N, 1)   # N by 1
  
  F[1,1] <- rnorm(1,0,1)   # r by 1
  F[1,2] <- rnorm(1,0,1)   # r by 1
  
  for (a in 2:T) {
    err_2[a,] <- (diag(1, N, N) + spatial*W1 + spatial^2*W2)%*%matrix(rnorm(N,0,1), N, 1)
    F[a, 1] <- rho*F[a-1, 1] + sqrt(1 - rho^2)*rnorm(1,0,1)
    F[a, 2] <- rho*F[a-1, 2] + sqrt(1 - rho^2)*rnorm(1,0,1)
  }
  
  # Generate regressors
  tau_t <- matrix(rep(1, T*r), T, r)
  tau_i <- matrix(rep(1, N*r), N, r)
  X_1 = F%*%t(L) + tau_t%*%t(L) + F%*%t(tau_i) + matrix(rnorm(N*T,0,1), T, N)
  
  ## Data Generate Process
  ## DGP in iid case
  Y <-  beta_1*X_1 + F%*%t(L) +  matrix(rnorm(N*T, 0, 1), T, N)
  
  # DGP with Cross sectional error
  Y_1 <- beta_1*X_1 + F%*%t(L) + err_2
  
  # Step 1: Estimate the interactive estimator, factors, loading and error terms 
  # Estimate for the coefficient
  # iid 
  Result <- IFE.new(Y, X_1, r)
  Beta_hat <- Result$beta
  
  # iid case
  R_bar_0 <- Y - Beta_hat*X_1
  Eigen_0 <- eigen(R_bar_0%*%t(R_bar_0)/(N*T))
  F_hat_0 <- sqrt(T)*Eigen_0$vectors[, 1:r]
  # Estimate loading matrix and error terms
  Lamda_hat_0 <-  (1/T)*t(Y - Beta_hat*X_1)%*%F_hat_0
  err_hat_0 <- Y - Beta_hat*X_1 - F_hat_0%*%t(Lamda_hat_0)
  
  # Estimate projection matrix
  M_F_0 <- diag(1, T, T) - (1/T)*F_hat_0%*%t(F_hat_0)
  a_0 <- matrix(NA, N, N)
  a_0 <-  Lamda_hat_0%*%solve(t(Lamda_hat_0)%*%Lamda_hat_0/N)%*%t(Lamda_hat_0)
  Z_hat_0 <- M_F_0%*%X_1 - (1/N)*(M_F_0%*%X_1%*%a_0)
  
  # Variance for iid case
  D_0 <- sum(Z_hat_0^2)/(T*N)
  sigma_hat_0 <- sum(err_hat_0^2)/(N*T) 
  var_beta_0 <- solve(D_0)*sigma_hat_0
  
  # Standard error for iid case
  se0 <- sqrt(var_beta_0/(N*T))
  
  # Cross sectional error
  Result_1 <- IFE.new(Y_1, X_1, r)
  Beta_hat_1 <- Result_1$beta
  
  # PCA decomposition
  # Estimate factor matrix
  R_bar <- Y_1 - Beta_hat_1*X_1
  Eigen <- eigen(R_bar%*%t(R_bar)/(N*T))
  F_hat <- sqrt(T)*Eigen$vectors[, 1:r]
  
  # Estimate loading matrix and error terms
  Lamda_hat <-  (1/T)*t(Y_1 - Beta_hat_1*X_1)%*%F_hat
  err_hat <- Y_1 - Beta_hat_1*X_1 - F_hat%*%t(Lamda_hat)
  
  
  # Construct the operational distance matrix that reflects the degree of dependence 
  # err_hat_df <- data.frame(rep(c(1:N),each=T),rep(c(1:T),times=N),c(err_hat))
  # colnames(err_hat_df) <- c("id","time","err_hat")
  # err_hat_temp <- dcast(err_hat_df, time~id, value.var="err_hat")
  # err_cor <- cor(err_hat_temp[, -1])
  # D_temp <- 1/abs(err_cor)
  # for (i in 1:N) {
  #   for (j in 1:N) {
  #     if (D_temp[i,j] >= 100)
  #       D_temp[i,j] <- 100
  #   }
  # }
  # D_hat <- D_temp - 1
  
  # Use the true distance matrix
  D_hat <- D
  
  # Empty matrix for the results of estimators
  Reject_ratio <- matrix(NA, nrow(d_comb_hac), 1)
  
  # Select the optimal bandwidth by bootstrap method
  for (d in 1:nrow(d_comb_hac)) {
    
    ## Bandwidth selection
    d_1 <- d_comb_hac[d,1]
    d_2 <- d_comb_hac[d,2]
    
    ## Kernel density matrix for the first HAC estimator
    D_kel_1 <- D_hat/d_1
    # Parzen Kernel
    Ker1 <-  (1- 6*D_kel_1^2 + 6*abs(D_kel_1)^3)*(abs(D_kel_1) <= 0.5) + 2*(1-abs(D_kel_1))^3*(abs(D_kel_1) > 0.5)*(abs(D_kel_1) <= 1);
    
    ## Kernel density matrix for the second HAC estimator
    D_kel_2 <- D_hat/d_2
    # Parzen Kernel
    Ker2 <-  (1- 6*D_kel_2^2 + 6*abs(D_kel_2)^3)*(abs(D_kel_2) <= 0.5) + 2*(1-abs(D_kel_2))^3*(abs(D_kel_2) > 0.5)*(abs(D_kel_2) <= 1);
    
    # Bootstrap function
    boot_fx <- function(b){
      
      # Step 2: Generate boostrap samples
      # Generate the bootsprap error terms
      err_star <- matrix(NA, T, N)
      
      for (t in 1:T) {
        err_star[t, ] <- err_hat[t,]*rsign(1)
      }
      
      # Bootstrap DGP
      Y_star <- matrix(NA, T, N)
      
      for (t in 1:T) {
        Y_star[t, ] <- Beta_hat_1*X_1[t, ] + F_hat[t,]%*%t(Lamda_hat) + err_star[t,] 
      }
      
      # Step 3 Estimate the bootstrap version of interactive estimator, 
      # factors , loading and error terms 
      Result_star <- IFE.new(Y_star, X_1, r)
      Beta_hat_star <- Result_star$beta
      
      # PCA decomposition
      # Estimate factor matrix
      R_bar_star <- Y_star - Beta_hat_star*X_1
      Eigen_star <- eigen(R_bar_star%*%t(R_bar_star)/(N*T))
      F_hat_star <- sqrt(T)*Eigen_star$vectors[, 1:r]
      
      # Estimate loading matrix and error terms
      Lamda_hat_star <-  (1/T)*t(Y_star - Beta_hat_star*X_1)%*%F_hat_star
      err_hat_star <- Y_star - Beta_hat_star*X_1 - F_hat_star%*%t(Lamda_hat_star)
      
      # Construct the bootstrap version of bias term B_star
      # Estimate the bootstrap matrix A in the bias term B_star
      A_hat_star <- solve((1/N)*t(Lamda_hat_star)%*%Lamda_hat_star)
      
      # Estimate the bootstrap version of projection matrix
      M_F_star <- diag(1, T, T) - (1/T)*F_hat_star%*%t(F_hat_star)
      
      # Estimate the bootstrap version of p*p matrix D(F)
      a_star <- matrix(NA, N, N)
      a_star <-  Lamda_hat_star%*%solve(t(Lamda_hat_star)%*%Lamda_hat_star/N)%*%t(Lamda_hat_star)
      Z_hat_star <- M_F_star%*%X_1 - (1/N)*(M_F_star%*%X_1%*%a_star)
      
      # Estimate the bootstrap version of matrix D(F)
      D_F_star <- matrix(NA, N, 1)
      for (i in 1:N) {
        D_F_star[i,1] <- (1/T)*t(Z_hat_star[,i])%*%Z_hat_star[,i]
      }
      D_F_star <- mean(D_F_star)
      
      # Estimate for the bootstrap version of matrix V in the bias term B
      V_hat_star <- (1/N)*X_1%*%a_star
      
      # Compute the bootstrap version of W_hat
      W_hat_star <- (1/T)*t(X_1 - V_hat_star)%*%F_hat_star
      
      # The bootstrap version of Spatial HAC estimation 
      M_star <- (((W_hat_star%*%A_hat_star%*%t(Lamda_hat_star)))*(t(err_hat_star)%*%err_hat_star/T))*Ker1
      M_average_star <- sum(M_star)/N
      B_hat_star <- -solve(D_F_star)*M_average_star
      
      # The bootstrap version of Bias Corrected estimators
      Beta_cor_star <-  Beta_hat_star - B_hat_star/N
      
      # Step 4:  Estimate the bootstrap version of covariance matrices 
      # Estimating the Covariance Matrices
      D_0_hat_star <- sum(Z_hat_star^2)/(T*N)
      # Cross section error by spatial HAC method
      D_1_hat_star <- sum((t(Z_hat_star*err_hat_star)%*%(Z_hat_star*err_hat_star))*Ker2)/(N*T)
      
      # variace for cross section error
      var_beta_hac_star <- (solve(D_0_hat_star)^2)*D_1_hat_star
      
      # Standard error for cross section error
      se_star <- sqrt(var_beta_hac_star/(N*T))   
      
      # Step 5: Compute the bootstrap based t-test statistics
      t_star <- (Beta_cor_star - Beta_hat_1)/se_star
      
      # Step 6: count how many t_star values are out of (-1.96, 1.96)
      if (abs(t_star) > 1.96){
        C <- 1
      } else {
        C <- 0
      }
      return(C)
    }
    
    # Run the bootstrap function within cluster
    C_star <- foreach (b=1:B, .combine=c) %dopar% {
      library(extraDistr)
      boot_fx(b)
    }
    
    # calculate the ratio of the number of t_star values are out of (-1.96, 1.96) with B bootstrap samples
    Reject_ratio[d,1] <- sum(C_star)/B
    
  } # pairs of bandwidth we choose
  
  # Optimal bandwidth choose
  Opt <- cbind(d_comb_hac, Reject_ratio)
  Opt.band <- Opt[which.min(Opt[,3]),][,1:2]
  
  # Construct the bias term B
  # Estimate the matrix A in the bias term B
  A_hat <- solve((1/N)*t(Lamda_hat)%*%Lamda_hat)
  
  # Estimate projection matrix
  M_F <- diag(1, T, T) - (1/T)*F_hat%*%t(F_hat)
  
  for (o in 1:3) {
    
    # Estimate the p*p matrix D(F)
    a <- matrix(NA, N, N)
    a <-  Lamda_hat%*%solve(t(Lamda_hat)%*%Lamda_hat/N)%*%t(Lamda_hat)
    Z_hat <- M_F%*%X_1 - (1/N)*(M_F%*%X_1%*%a)
    
    # Estimate the matrix D(F)
    D_F_1 <- matrix(NA, N, 1)
    for (i in 1:N) {
      D_F_1[i,1] <- (1/T)*t(Z_hat[,i])%*%Z_hat[,i]
    }
    D_F <- mean(D_F_1)
    
    ## Using the optimal Bandwidth selected before
    d_1_star <- Opt.band[1,1]
    d_2_star <- Opt.band[1,2]
    
    # Parzen Kernel
    ## Kernel density matrix for the first HAC estimator
    D_kel_1 <- D_hat/d_1_star
    # Parzen Kernel
    Ker1_star <-  (1- 6*D_kel_1^2 + 6*abs(D_kel_1)^3)*(abs(D_kel_1) <= 0.5) + 2*(1-abs(D_kel_1))^3*(abs(D_kel_1) > 0.5)*(abs(D_kel_1) <= 1);
    ## Kernel density matrix for the second HAC estimator
    D_kel_2 <- D_hat/d_2_star
    # Parzen Kernel
    Ker2_star <-  (1- 6*D_kel_2^2 + 6*abs(D_kel_2)^3)*(abs(D_kel_2) <= 0.5) + 2*(1-abs(D_kel_2))^3*(abs(D_kel_2) > 0.5)*(abs(D_kel_2) <= 1);
    
    # Estimate for matrix V in the bias term B
    V_hat <- (1/N)*X_1%*%a
    
    # Compute W_hat
    W_hat <- (1/T)*t(X_1 - V_hat)%*%F_hat
    
    # Spatial HAC estimation 
    # Method 1: using matrix
    M <- (((W_hat%*%A_hat%*%t(Lamda_hat)))*(t(err_hat)%*%err_hat/T))*Ker1_star
    M_average <- sum(M)/N
    B_hat <- -(D_F)^(-1)*M_average
    
    # Bias Corrected estimators
    Beta_cor <-  Beta_hat_1 - B_hat/N
    
    R_bar <- Y_1 -  Beta_cor*X_1
    Eigen <- eigen(R_bar%*%t(R_bar)/(N*T))
    F_hat <- sqrt(T)*Eigen$vectors[, 1:r]
    
    Lamda_hat <-  (1/T)*t(Y_1 - Beta_cor*X_1)%*%F_hat
    err_hat <- Y_1 - Beta_cor*X_1 - F_hat%*%t(Lamda_hat)
    
    # Estimate the matrix A in the bias term B
    A_hat <- solve((1/N)*t(Lamda_hat)%*%Lamda_hat)
    
    # Estimate projection matrix
    M_F <- diag(1, T, T) - (1/T)*F_hat%*%t(F_hat)
    
  }  
  
  # Estimating the Covariance Matrices
  D_0_hat <- sum(Z_hat^2)/(T*N)
  
  # Cross section error by spatial HAC method
  D_1_hat <- sum((t(Z_hat*err_hat)%*%(Z_hat*err_hat))*Ker2_star)/(N*T)
  
  # Variance for iid case
  sigma_hat <- sum(err_hat^2)/(N*T) 
  var_beta <- solve(D_0_hat)*sigma_hat
  
  # variace for cross section error
  var_beta_hac <- (solve(D_0_hat)^2)*D_1_hat
  
  # Standard error for normal case
  se1 <- sqrt(var_beta/(N*T))
  # Standard error for cross section error
  se2 <- sqrt(var_beta_hac/(N*T)) 
  
  # WPC in Bai and Liao (2012)
  Sigu <- Matrix_fun(err_hat, 1) # can also replace 1 with a slightly smaller value (e.g., 0.5, 0.7)
  Result_2 <- IFE.WPC(Y_1, X_1, Sigu, r)
  Beta_hat_WPC <- Result_2$beta
  
  # PCA decomposition
  # Estimate factor matrix
  R_WPC <- Y_1 - Beta_hat_WPC*X_1
  Eigen_WPC <- eigen(R_WPC%*%t(R_WPC)/(N*T))
  F_hat_WPC <- sqrt(T)*Eigen_WPC$vectors[, 1:r]
  
  # Estimate loading matrix and error terms
  Lamda_hat_WPC <-  (1/T)*t(Y_1 - Beta_hat_WPC*X_1)%*%F_hat_WPC
  err_hat_WPC <- Y_1 - Beta_hat_WPC*X_1 - F_hat_WPC%*%t(Lamda_hat_WPC)
  
  # Estimating the Covariance Matrices for Bai and liao (2012)
  # Estimate projection matrix
  M_F_1 <- diag(1, T, T) - (1/T)*F_hat_WPC%*%t(F_hat_WPC)
  
  # Estimate the weighted matrix D(F)
  Q <- solve(Sigu)
  a_1 <- matrix(NA, N, N)
  a_1 <-  Lamda_hat_WPC%*%solve(t(Lamda_hat_WPC)%*%Q%*%Lamda_hat_WPC/N)%*%t(Lamda_hat_WPC)
  ZZ_hat <- M_F_1%*%X_1%*%Q - (1/N)*(M_F_1%*%X_1%*%Q%*%a_1%*%Q)
  
  # Estimating the Covariance Matrices
  ZZ_vector_1 <- matrix(ZZ_hat, N*T, 1)
  D_1 <- t(ZZ_vector_1)%*%ZZ_vector_1/(N*T)
  
  # variance and standard error in Bai and liao (2012)
  varia <- (solve(D_1)^2)*sum((t(ZZ_hat)%*%ZZ_hat)*(Sigu))/(N^2*T^2)
  standard <- sqrt(varia)
  
  # Bias terms 
  Bias_PC  <-  abs(Beta_hat_1 - 1)
  Bias_WPC <-  abs(Beta_hat_WPC - 1)
  Bias_HAC <-  abs(Beta_cor - 1)
  
  # MSE
  MSE_PC  <-  (Beta_hat_1 - 1)^2
  MSE_WPC <-  (Beta_hat_WPC - 1)^2
  MSE_HAC <-  (Beta_cor - 1)^2
  
  # t-statistics for iid case
  t_0 <- (Beta_hat - beta_1)/se0
  # Count how many t_1 values are out of (-1.96, 1.96)
  if (abs(t_0) > 1.96){
    C_0 <- 1
  } else {
    C_0 <- 0
  }
  
  # t-statistics for cross sectional case without bias correction
  # use iid covariance matrix
  t_1 <- (Beta_hat_1 - beta_1)/se1 
  # Count how many t_1 values are out of (-1.96, 1.96)
  if (abs(t_1) > 1.96){
    C_1 <- 1
  } else {
    C_1 <- 0
  }
  
  # t-statistics for cross sectional case without bias correction
  # Covariance matrix estimated by SHAC
  t_2 <- (Beta_hat_1 - beta_1)/se2 
  # Count how many t_2 values are out of (-1.96, 1.96)
  if (abs(t_2) > 1.96){
    C_2 <- 1
  } else {
    C_2 <- 0
  }
  
  # t-statistics for bias corrected by SHAC case 
  # use iid covariance matrix
  t_3 <- (Beta_cor - beta_1)/se1 
  # Count how many t_3 values are out of (-1.96, 1.96)
  if (abs(t_3) > 1.96){
    C_3 <- 1
  } else {
    C_3 <- 0
  }
  
  # t-statistics for bias corrected by SHAC case 
  # Covariance matrix estimated by SHAC
  t_4 <- (Beta_cor - beta_1)/se2 
  # Count how many t_4 values are out of (-1.96, 1.96)
  if (abs(t_4) > 1.96){
    C_4 <- 1
  } else {
    C_4 <- 0
  }
  
  # # t-statistics for Bai and liao (2012)
  t_5 <- (Beta_hat_WPC - 1)/standard
  # Count how many t_5 values are out of (-1.96, 1.96)
  if (abs(t_5) > 1.96){
    C_5 <- 1
  } else {
    C_5 <- 0
  }
  
  Result_total <- c(d_1_star, d_2_star, Bias_PC, MSE_PC, Bias_WPC, MSE_WPC, Bias_HAC, MSE_HAC,
                    C_0, C_1, C_2, C_3, C_4, C_5)
  
  return(Result_total) 
  
}


# Set up the reasonable bandwidth choices for the two HAC estimators in cluster
d_1 = d_2 = 5
# d_1 <- c(seq(3,10,1))
# d_2 <- c(seq(3,10,1))
d_comb_hac <- expand.grid(d_1, d_2) # combinations of the pairs of bandwidth
d_comb_hac


# number of repetitions
S = 1000

Result_all <- foreach (s=1:S, .combine=rbind) %dopar% {
  library(Metrics)
  library(pracma)
  library(MASS)
  library(xts)
  library(plm)
  library(Metrics)
  library(foreach)
  library(reshape2)
  library(extraDistr)
  # print(paste("S=", s, "d=", d, "B=",b))
  Bandwidth_opt(144, 50, 0.4, 0.3, s, 100)
}


# Optmal bandwidth choose
opt_bandwidth <- matrix(NA, S, 2)
for (s in 1:S) {
  opt_bandwidth[s,] <- Result_all[s,1:2]
}
opt_bandwidth

# Bias terms and MSE
Result_total <- colSums(Result_all[,3:14])/S

# RMSE
Result_total[2] <- sqrt(Result_total[2])
Result_total[4] <- sqrt(Result_total[4])
Result_total[6] <- sqrt(Result_total[6])
# Bias terms and RMSE
Result_Bias_MSE <- round(Result_total[1:6], 4)
Result_Bias_MSE
# Empirical Rejection rate
Result_Rej <- round(Result_total[7:12], 3)
Result_Rej
Result_Epc <- 1 - Result_Rej
Result_Epc

# When you're done, clean up the cluster
stopImplicitCluster()

