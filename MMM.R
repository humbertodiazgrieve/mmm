############################################################################################################
## STEP 0: SET THE ENVIRONMENT
## Installing Facebook Robyn
install.packages("Robyn")
library("Robyn")
set.seed(123)


Sys.setenv(R_FUTURE_FORK_ENABLE="True")
options(future.fork.enable = TRUE)

## INSTALL NEVERGRAND
## 1. Install Reticulate in the R console BY printing this in the R terminal install.packages("reticulate")
# in the r console print: install.packages("reticulate")
library("reticulate") 
virtualenv_create("r-reticulate")
use_virtualenv("r-reticulate", required=TRUE)
py_install("nevergrad", pip=TRUE)

############################################################################################################
## STEP 1: LOAD DATA
data("dt_simulated_weekly")
data("dt_prophet_holidays")

## CREATE A ROBYN OBJECT
## it must be named different than robyn and must have the .RDS extention
robyn_object <- "C:/Users/PCR-LAP21084030/Downloads/ROBYN_PROJECTION/MyRobyn.RDS"

############################################################################################################
## STEP 2A: para primariosos, hay que setear las especificaciones del modelo
## STEP 2A-1: INPUT DATA AND MODEL PARAMETERS

InputCollect <- robyn_inputs(
  dt_input = dt_simulated_weekly
  #dt_input = data.table::fread('path.csv')
  , dt_holidays = dt_prophet_holidays
  
  ### set variables
  ,date_var = 'DATE' # el dateformat debe ser '2023-04-02'
  ,dep_var = 'revenue' # solo puede haber una variable independiente
  ,dep_var_type = 'revenue' # puede ser revenue o conversion. Siempre debe ser asi, es una robyn keyword
  
  ### prophet vars
  ,prophet_vars = c('trend','season','holiday') # puede ser 'trend', 'season', 'weekday', 'holiday'
  ,prophet_signs = c('default','default','default') # c('default','positive','negative'). Se recomienda que sea default y que el largo del c() sea el mismo que prophet_vars
  # estos signos indican el impacto que tiene la variable en el negocio. Se coloca default porque no sabemos que impacto tendra la tendencia o el feriado.
  ,prophet_country = "PE" # solo se permite un pais
  
  ### context vars: nos afectan pero no son factores en los que estamos invirtiendo dinero
  ,context_vars = c('competitor_sales_B', 'events') # estas variables pueden ser precios, promociones, temepratura, tasa de desempleo, etc
  ,context_signs = c('default','default') # c('default','positive','negative'). En este caso, un evento podria generar un impacto positivo en las ventas
  
  ### paid media vars
  ,paid_media_vars = c('tv_S', 'ooh_S', 'print_S', 'facebook_I', 'search_clicks_P') # es recomendable usar impreisones en vez de clics
  ,paid_media_signs = c('positive','positive','positive','positive','positive') # se espera que el gasto tenga un impacto positivo en la rentabilidad
  ,paid_media_spends = c('tv_S', 'ooh_S', 'print_S', 'facebook_S', 'search_S')
  
  ### organic vars
  ,organic_vars = c('newsletter')
  ,organic_signs = c('positive')
  
  ### factorial vars
  ,factor_vars = c('events') # especificamos que varialbes de contexto u organicas son factoriales 'si' o 'no'
  
  #### setear parametros del modelo
  
  ### set cores for parallel computing
  ,cores = 4
  
  ### (opcional)setting rolling window start:  con esto le decirmos a robyn que se entrene con toda nuestra data pero que se enfoque en ese periodo de tiempo
  ,window_start = "2016-11-23"
  ,window_end = "2018-08-22"
  # esta ventana de tiempo es la mejor define mi actividad en paid_media
  
  ### set core features
  ,adstock = 'geometric' # puede ser geometric, weibull_cdf, weibull_pdf. Geometric is faster and easier.
  # weibull_pdf is a most accurate algorithym because take into account the decay rate over time. 
  
  ,iterations = 2000
  # geometric = 2000
  # weibull_cdf = 4000
  # weibull_pdf = 6000
  
  ,trials = 5 # se recomiendan 5 sin calibracion y 10 con calibracion
  
  ,intercept_sign = 'non-negative' # Si invierto CERO en cada canal, cuanto generare. Debe ser no negatrivo, porque asi no inviertas en publidad, no se logran ventas negativas
  ,nevergrad_algo = 'TwoPointsDE' # el algoritmo que usara nevergrad para optimizar parametros
  
  )

## STEP 2A-2: DEFINIR Y AGREGAR HIYPERPARAMETERS

## 1: Solicitamos los hyper parameters names
hyper_names(adstock=InputCollect$adstock,all_media = InputCollect$all_media)

## 2: Especificamos limites para cada hyperparameter de los canales.
## IMPORTANTE: estos limites van a ser diferentes dependiendo el dataset, los canales, todo...

hyperparameters <- list(
  ### facebook hyperparameters
  facebook_S_alphas = c(0.5, 3)
  ,facebook_S_gammas = c(0.3,1)
  ,facebook_S_thetas = c(0,0.3)
  
  ### print hyperparameters
  ,print_S_alphas = c(0.5, 3)
  ,print_S_gammas = c(0.3,1)
  ,print_S_thetas = c(0.1,0.4)
  
  ### ooh hyperparameters
  ,ooh_S_alphas = c(0.5, 3)
  ,ooh_S_gammas = c(0.3,1)
  ,ooh_S_thetas = c(0.1,0.4)
  
  ### tv hyperparameters
  ,tv_S_alphas = c(0.5, 3)
  ,tv_S_gammas = c(0.3,1)
  ,tv_S_thetas = c(0.3,0.8)
  
  ### search hyperparameters
  ,search_S_alphas = c(0.5, 3)
  ,search_S_gammas = c(0.3,1)
  ,search_S_thetas = c(0.1,0.4)
  
  ### newsletter hyperparameters
  ,newsletter_alphas = c(0.5, 3)
  ,newsletter_gammas = c(0.3,1)
  ,newsletter_thetas = c(0.1,0.4)
  
)

## STEP 2A-3: AGREGAR HYPERPARAMETERS EN robyn_inputs()

InputCollect <- robyn_inputs(InputCollect = InputCollect, hyperparameters = hyperparameters)

############################################################################################################
## STEP 3: BUILDING THE INITIAL MODEL

## 1: RUN ALL TRIALS AND ITERATIONS
## USE ROBYN RUN TO CHECK PARAMETER DEFINITION

OutputModels <- robyn_run(
  InputCollect = InputCollect
  , outputs = FALSE
)

OutputCollect <- robyn_outputs(
  InputCollect, OutputModels
  , pareto_fronts = 1
  , csv_out = "pareto"
  , clusters = TRUE
  , plot_pareto = TRUE
  , plot_folder = robyn_object
)