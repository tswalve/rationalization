# Power calculations for rationalization of party choice through missreporting 
# of ideological positions
# Fridolin Linder
rm(list = ls())
library(ggplot2)
library(truncnorm)
library(randomForest)

# Getting realisitc estimates for pars of distribution of self position
# from anes and mturk prerun
setwd("C:/Users/fridolin linder/Dropbox/rationalization/rationalization")

## ANES
anes <- read.table('data/anes/anes.csv')
as <- anes$libcpre_self
as_norm <- (as - min(as)) / (max(as) - min(as))
var(as_norm)
plot(density(as_norm, bw = 0.12, from = 0, to = 1), lwd = 2)
x <- seq(0, 1, by = 0.01)
points(x, dtruncnorm(x, 0, 1, 0.5, 0.3), type = 'l', lty = 2, lwd = 2, 
       col = 'red')

## MTurk Prerun
pre <- read.table('data/prerun/rat_prerun.csv', sep = ",")
pre$self_eg1_s <- ((pre$self_eg1 - min(pre$self_eg1, na.rm = T)) / 
                     (max(pre$self_eg1, na.rm = T) - min(pre$self_eg1, na.rm = T)))
pre$self_eg2_s <- ((pre$self_eg2 - min(pre$self_eg2, na.rm = T)) / 
                     (max(pre$self_eg2, na.rm = T) - min(pre$self_eg2, na.rm = T)))
var(pre$self_eg1_s, na.rm = T)
var(pre$self_eg2_s, na.rm = T)

## Get variance for difference between prediction and report from the prerun

# Recode climate change question
pre$gwhow[is.na(pre$gwhow)] <- pre$gwhow2[!is.na(pre$gwhow2)]
pre$gwhow2 <- NULL

# Train predictive model
mod <- self_eg1_s ~ hltref + gaymarry + gayadopt + abrtch + abrthlth + abrtinc + 
  abrtbd + abrtrpe + abrtdth + abrtfin + fedenv + fedwlf + fedpoor + fedschool + 
  drill + gwhap + gwhow + aauni + aawork + gun + comm
fit <- randomForest(mod, data = pre[pre$group == 1, ],  importance = T)

# Predicions
pred <- predict(fit)
sqrt(var((na.omit(pre$self_eg1_s) - pred)^2))


# ==============================================================================
# Parametric Power Analysis
# Power for a two sample t-test (assuming known true self position)

# Experiment 1: Bias in Self
# Compare mean squared difference between reported and predicted self
# assuming equal standard deviation of 0.5 in both groups 
# (see writeup for details)

power.t.test(delta = .05, power = .9, sd = 0.06, type = "two.sample", 
             alternative = "one.sided", sig.level = 0.05)

plot(density((pre$self - pred)^2, bw = 0.1, from = 0, to = 1), lwd = 2)
x <- seq(0, 1, by = 0.01)
points(x, dtruncnorm(x, 0, 1, 0.5, 0.3), type = 'l', lty = 2, lwd = 2, 
       col = 'red')

# ==============================================================================
# Non-Parametric Power Analysis
# Simulating data according to hypothesized DGP 


### Function simulating the data generating process for experiment 2. 
### Assuming the true self position is known in both groups
#
## Arguments:
# N: number of samples
# md: mean of distribution from which the bias parameter is drawn
# p1,p2: fixed 'objective' positions of parties 1 and 2
# v: standard deviation of voters perception error for the party positions
# 
## The DGP wotks as follows
# Voters Ideal points drawn from ~truncN(.5,.3,0,1)
# Their perception of the two parties' positions is drawn from N(p1,v),N(p2,v)
# Their prefered party is selected by minimizing the distance between self and 
# perceived party position
# Subjects in the treatment condition report biased candidate postieions where 
# the individual bias is calculated by drawing a bias parameter d from 
# truncN(md,.05,0,1), then rp_i = pp_i + d_i*(pp_i-ts_i), where, 
# rs: reported party position, ts: true self, 
# pp: perceived party and i = 1,...,N are the subjects
#

genData <- function(N, md = .5, p1 = .2, p2 = .8, v = .1){
  require(truncnorm)
  ts <- rtruncnorm(N, 0, 1, .5, .2) # true self position
  pp <- cbind(rtruncnorm(N, 0, 1, p1, v), rtruncnorm(N, 0, 1, p2, v)) # perc part pos
  dtf <- apply(ts - pp, 1, function(x) x[which.min(abs(x))]) # distance to favorite
  fp <- apply(abs(pp - ts), 1, which.min) # favorite party
  d <- c(rnorm(N / 2, md, .1), rep(0, N / 2)) # Bias par 0 for control group
  tpp <- apply(cbind(pp, fp), 1, function(x) x[x[3]]) # true perceived pos of prefered party
  rp <- tpp + d * dtf # reported party  =  perceived party + bias
  data.frame('rep_self' = ts,'rep_party' = rp, "true_party" = tpp, 'fav_party' = fp,
             'group' = c(rep(1,N/2),rep(0,N/2)), "d" = d)
}

# Demo
N <- 1e4
X <- genData(N)
dist <- abs(X$rep_self - X$rep_party)
hist(dist[X$group == 0], breaks = 30,col = 'grey') # Control Group
hist(dist[X$group == 1], breaks = 30,col = 'grey') # Treatment Group
mean(dist[X$group == 1]) / mean(dist[X$group == 0])

# Function to generate data and calcualte difference in mean abs distance
diff <- function(md, N, ratio = T){
  X <- genData(N, md = md)
  dist <- abs(X$rep_self - X$rep_party)
  if(!ratio) mean(dist[X$group == 0]) - mean(dist[X$group == 1])
    else mean(dist[X$group == 1]) / mean(dist[X$group == 0])
}

# Function to Sample difference/ratio of means
sampDiff <- function(B, N, md) sapply(rep(md, B), diff, N = N)

### Power analysis by simulation
cis <- list()
d <- c(.05, .1, .2, .5)
N <- list(10, 100, 200, 500, 1000)
B <- 1000

for(i in 1:length(d)){
  print(d[i])
  md <- d[i] # Reduction of distance by 100*d[i]%
  distns <- lapply(N, sampDiff, B = B,md = md)
  ci <- do.call(rbind, lapply(distns, quantile, c(.025, .975)))
  cis[[i]] <- ci
}
#save(file='data/ci.RData','cis')
#load(file = "data/ci.RData")

# Plot it
df <- as.data.frame(do.call(rbind, cis))
df$bias <- as.factor(rep(d, each = 5))
df$N <- as.factor(rep(1:5, 4))
levels(df$N) <- c("10", "100", "200", "500", "1000")


colnames(df) <- c("lo", "hi", "bias", "N")

p <- ggplot(df,aes(bias, lo, hi, color = N))
#p <- p + facet_wrap(~ d, ncol = 2, scales = "fixed")
p <- p + geom_errorbar(aes(x = bias, ymin = lo, ymax = hi), position = "dodge", width = .5)
p <- p + geom_hline(yintercept = 1)
#p <- p + coord_flip()
p <- p + ylab('Ratio of Mean Absolute Difference between S^ and C^') 
p <- p + xlab('Mean Bias (factor reduction in distance)')
p <- p + theme_bw()
ggsave("figures/power_sim.png", plot = p, width = 10, height = 6)




