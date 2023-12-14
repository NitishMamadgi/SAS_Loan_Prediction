proc import datafile= "/home/u63491025/sasuser.v94/excel_files/loan_prediction_SAS.csv"
	dbms=csv out=project.loan_prediction replace;
	getnames=yes;
run;

data loan_prediction(drop = loan_history loan_duration);
	set project.loan_prediction;
	
    informat guarantee_income loan_amount candidate_income 8.;   /* Apply informats and formats */
    format guarantee_income loan_amount candidate_income 8.;
    
    LOAN__HISTORY = put(loan_history, 1.);						* Convert from numeric to character;
    LOAN__DURATION = put(loan_duration, 3.);
	
	informat LOAN__HISTORY $1. LOAN__DURATION $3.;
	format LOAN__HISTORY $1. LOAN__DURATION $3.;
	
	rename LOAN__HISTORY = LOAN_HISTORY LOAN__DURATION = LOAN_DURATION;
run;


/* Display information about the dataset */

proc contents data= loan_prediction;
run;

/* Retain only the first instance of duplicates */

proc sort data=loan_prediction nodupkey;
	by _all_;
run;


/* Proc means to check missing values;*/

proc means data=loan_prediction maxdec=2 n nmiss mean median max min;
	var _numeric_;
run;

				


/* Proc freq to check missing values for character variables;*/
%let char = gender marital_status family_members qualification employment loan_location loan_history loan_duration;

proc freq data=loan_prediction  ;
	tables &char. / nocum;
run;

proc freq data=loan_prediction;
	table loan_approval_status/ nocum;
run;



/* Create a Macro to impute 'mean' value for numeric missing values */

%macro impute_missing_with_mean(data, var);
    PROC STDIZE DATA = &data REPONLY METHOD = mean OUT=&data;
        VAR &var;
    QUIT;
    
    proc means data= &data. n nmiss;
    	var &var.;
    run;
%mend;

%impute_missing_with_mean(loan_prediction, loan_amount);


/* Create a Macro to impute 'mode' value for character missing values */
/* Missing values --> gender - 13 , marital_status - 3, family_members - 15 , employment - 32 */


%macro impute_missing_with_mode(data, var);
	proc sql;							
		create table mode_var as					
		  select &var. AS mode_var
		  from &data.
		  group by &var.
		  having COUNT(&var.) = (
		    select max(freq)
		    from (
		      select count(&var.) AS freq
		      from &data.
		      group by &var.
		    )
		  )
		  ;
	quit;
	
	proc sql;								
		update &data.
		set &var. = (select mode_var from mode_var)
		where &var. in (""," ",".","  .");
	quit;
%mend;

%impute_missing_with_mode(loan_prediction, gender);
%impute_missing_with_mode(loan_prediction, marital_status);
%impute_missing_with_mode(loan_prediction, family_members);
%impute_missing_with_mode(loan_prediction, employment);
%impute_missing_with_mode(loan_prediction, loan_duration);
%impute_missing_with_mode(loan_prediction, loan_history);


/* Analyse Character Variables with bar graphs */

%macro Analyse_Char_Variable(data, var);
	proc freq data=&data.;
		table &var./nocum;
	run;
	
	proc sgplot data=&data.;
		vbar &var.;
	run;
%mend;


%Analyse_Char_Variable(loan_prediction,gender);
%Analyse_Char_Variable(loan_prediction,marital_status);
%Analyse_Char_Variable(loan_prediction,family_members);
%Analyse_Char_Variable(loan_prediction,qualification);
%Analyse_Char_Variable(loan_prediction,employment);
%Analyse_Char_Variable(loan_prediction,loan_location);
%Analyse_Char_Variable(loan_prediction,loan_history);
%Analyse_Char_Variable(loan_prediction,loan_duration);
%Analyse_Char_Variable(loan_prediction,loan_approval_status);


/* macro to Analyse the Numerical Variables */
%macro Analyse_Num_Variable(data, var);
	proc means data=&data. maxdec=2;
		var &var.;
	run;
	
	proc sgplot data=&data.;
		histogram &var.;
	run;
%mend;

%Analyse_Num_Variable(loan_prediction, candidate_income);
%Analyse_Num_Variable(loan_prediction, guarantee_income);
%Analyse_Num_Variable(loan_prediction, loan_amount);


/* Check for multicollinearity between numeric variables */
proc corr data=loan_prediction nosimple noprob;
	var candidate_income guarantee_income loan_amount ;
	with candidate_income guarantee_income loan_amount;
run;



/* Let's do cross tabulations for categorical variables with "loan_approval_status" */
%macro cross_tabulate_Output(data,var);
	proc freq data=&data.;
		table &var.*loan_approval_status/ nocol nopercent;
	run;
	
	proc sgplot data= &data.;
		vbar &var./group = loan_approval_status groupdisplay = cluster;
%mend;


%cross_tabulate_Output(loan_prediction, gender);
%cross_tabulate_Output(loan_prediction, marital_status);
%cross_tabulate_Output(loan_prediction, family_members);
%cross_tabulate_Output(loan_prediction, qualification);
%cross_tabulate_Output(loan_prediction, employment);
%cross_tabulate_Output(loan_prediction, loan_location);
%cross_tabulate_Output(loan_prediction, loan_history);
%cross_tabulate_Output(loan_prediction, loan_duration);


/* Let's do comparision between 'loan_approval_status' and numeric variables; */
%macro vbox_Output(data,var);
	proc sgplot data=&data.;
		vbox &var./ group=loan_approval_status;
	run;
%mend;

%vbox_Output(loan_prediction, candidate_income);
%vbox_Output(loan_prediction, guarantee_income);
%vbox_Output(loan_prediction, loan_amount);



/* Need to remove outliers from the numerical data */
%macro remove_outliers(data,var);
	proc univariate data= &data. noprint;
	    var &var.;
	    output out=Summary pctlpts=25 75 pctlpre=P;
	run;
	
	data Summary;
		set Summary;
		upper_bound = P75 + 1.5*(P75 - P25);
		lower_bound = P25 - 1.5*(P75 - P25);
	run;
	
	proc sql;
	    create table CleanedData as
	    select lp.*
	    from &data. lp
	    where &var. >= (select lower_bound from Summary)
	      and &var. <= (select upper_bound from Summary);
	quit;
	
	data &data.;
		set CleanedData;
	run;
%mend;

%remove_outliers(loan_prediction, candidate_income);
%remove_outliers(loan_prediction, guarantee_income);
%remove_outliers(loan_prediction, loan_amount);

/* vbox -- check if the outliers are removed*/

%macro vbox(data, var);
	proc sgplot data=&data.;
		vbox &var.;
	run;
%mend;

%vbox(loan_prediction, candidate_income);
%vbox(loan_prediction, guarantee_income);
%vbox(loan_prediction, loan_amount);


data project.loan_prediction;
	set loan_prediction1;
run;



/* fit with logistic regression model */
proc logistic data=project.loan_prediction;

	class gender marital_status family_members qualification employment 
		  loan_location loan_history;

	model loan_approval_status (event = 'N') = gender marital_status family_members qualification 
								 employment loan_location loan_history
								 candidate_income guarantee_income loan_amount;
								 
	output out=LogisticOutput p=PredictedProbability;
run;


	/*Model Information:
	
	Data Set: PROJECT.LOAN_PREDICTION
	Response Variable: LOAN_APPROVAL_STATUS
	Number of Response Levels: 2 (Binary outcome)
	Model: Binary logistic regression
	Optimization Technique: Fisher's scoring
	Number of Observations Read: 520
	Number of Observations Used: 520
	Probability modeled is LOAN_APPROVAL_STATUS='N'.
	
	Response Profile:
	Ordered Value: The values of the response variable.
	LOAN_APPROVAL_STATUS: The outcome values ('N' and 'Y').
	Total Frequency: The frequency of each response level in the dataset.
	'N': 158 observations
	'Y': 362 observations
	
	Class Level Information:
	Each predictor variable (e.g., GENDER, MARITAL_STATUS) is listed with its possible values and 
	corresponding design variables. Design variables indicate how the original categorical values 
	are encoded for modeling.
	
	Model Convergence Status:
	It states that the convergence criterion (GCONV=1E-8) was satisfied, 
	indicating that the model's parameter estimates have converged and are stable.
	
	Model Fit Statistics:
	All the three AIC, SC and -2logL are methods for determining goodness of fit.
	Lower values are better -- so we chose 'Intercept and Covariates' instead of 'Intercept only' model
	
	Testing Global Null Hypothesis: BETA=0 --> test the overall significance of the model:
	-- Likelihood Ratio Test: The likelihood ratio chi-square statistic is 195.7279 with 13 degrees of freedom. 
	The p-value is less than 0.0001 (<.0001). This indicates strong evidence against the null hypothesis 
	(BETA=0) and suggests that at least one of the predictor variables in your model is significantly 
	associated with the outcome (LOAN_APPROVAL_STATUS), indicating that the model with predictor variables is a 
	significantly better fit than a model with no predictors.
	
	-- In summary, all three tests provide strong evidence that the model with predictor variables is 
	significant and that at least one of the predictor variables has a significant impact on the 
	likelihood of loan approval (LOAN_APPROVAL_STATUS). This suggests that your logistic regression model
	is a valuable tool for predicting loan approval based on the included covariates.
	
	Type 3 Analysis of Effects:
	This table provides information about the significance of each individual predictor variable
	in the model, taking into account the presence of other variables in the model.
	
	The Wald chi-square statistic tests the hypothesis that each predictor variable's coefficient (BETA) 
	is equal to zero (i.e., no effect). It quantifies how much the variable contributes to explaining the
	variation in the outcome.
	
	null hypothesis is beta = 0 i.e. no relationship btwn predictor variable and response variable. but if 
	p value is <0.05 then it means less chance of null hypothesis... i.e more relationship btwn var nd out.
	
	No significant  predictors - gender family_members employment 
	Borderline significant - marital_status qualification candidate_income guarantee_income  
	Significant -loan_location loan_history loan_amount 
	
	Odds Ratio Estimates:
	-- he odds ratio is a statistical measure used in logistic regression to quantify the strength 
	and direction of the relationship between a predictor variable and the outcome variable
	-- The point estimate represents the estimated odds ratio associated with each predictor variable. 
	An odds ratio greater than 1 indicates an increase in the odds of the event, while an 
	odds ratio less than 1 suggests a decrease.
	-- These are the confidence intervals for the odds ratios. They provide a range of values within 
	which the true odds ratio is likely to fall with 95% confidence. If CI includes 1 then thr is no 
	significant difference btwn the groups of the variables for predicting outcomes
	
	Association of Predicted Probabilities and Observed Responses:
	


		
	
	*/

	
	
	

