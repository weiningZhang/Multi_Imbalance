% Reference:
% Fernndez, B. A. & Baumela. L. (2014). Multi-class boosting with asymmetric binary weak-learners. Pattern
% Recognition, 2014, 47(5), PP. 2080-2090.
%
% PIBoost combines binary weak-learners to separate groups of classes, and uses a margin-based
% exponential loss function to classify multi-class imbalanced data.
%

function [time1,time2,ResultR0] = PIBoostcart(traindata,trainlabel,testdata,Max_Iter)

tic;
s=1;
labels=unique(trainlabel);
K=length(labels);
Y01=zeros(K,K);

% margin vectors through fixing a group of s-labels, and defining Y in the following way
for i=1:K
    Y01(i,i)=1;
end
Y=Y01;

for i=1:K
    for j=1:K
        if Y(i,j)==1
            Y(i,j)=1/s;
        else if Y(i,j)==0
            Y(i,j)=-1/(K-s);
        end
        end
    end
end

Learners = {};
% step 1: Initialize weight vectors
B=zeros(Max_Iter,size(Y,2));
weight = ones(1, length(trainlabel)) / length(trainlabel);
testpre={};

for m=1:Max_Iter
    for SNo=1:size(Y,2)
        Y01i=Y01(:,SNo);
        Yi=Y(:,SNo);
        trainlabelY=trainlabel;
        for i=1:K
            trainlabelY(trainlabel==labels(i))=Y01i(i);
        end

        % step 2(a) Fit a binary classifier Tms over training data with respect to its corresponding weight
        nb = treefit(traindata,trainlabelY,'weights',weight,'method','classification');

        Learners{m,SNo} = nb;

        Tms1=treeval(nb,traindata);
        Tms = Tms1;

        gms=Tms;
        gms(Tms==1)=1/s;
        gms(Tms~=1)=-1/(K-s);

        % step 2(b)  Compute 2 types of errors associated with Tms:
        Ttest1=treeval(nb,testdata);
        Ttest = Ttest1;
         
        gtest=Ttest;
        gtest(Ttest==1)=1/s;
        gtest(Ttest~=1)=-1/(K-s);
        testpre{m,SNo}=gtest;
        e1=0;
        e2=0;
        A1=0;
        A2=0;

        for i=1:length(gms)
            if trainlabelY(i)==1
                 A1=A1+weight(i);
                 if trainlabelY(i)~=Tms(i)
                     e1=e1+weight(i);
                 end
             else
                 A2=A2+weight(i);
                 if trainlabelY(i)~=Tms(i)
                     e2=e2+weight(i);
                 end
             end
         end
         if e1+e2<1e-20
            e1=1e-20;
            e2=1e-20;
         end

         % step 2(c) Calculate R, the only real positive root of the polynomial Pmx defined accordingto (8).
         syms x;
         Pmx=e1*(K-s)*(x^(2*K-2*s))+s*e2*x^K-s*(A2-e2)*(x^(K-2*s))-(K-s)*(A1-e1);
         x=solve(Pmx);
         x=double(x);
         xrealno=imag(x);
         xreal=real(x(abs(xrealno)<1e-5));
         R=xreal(find(abs(xreal)>1e-9));
         if length(R)>1
             R=max(R);
         end

         % step 2(d) Calculate B
         B(m,SNo)=s*(K-s)*(K-1)*log(R);
          for i=1:length(gms)%step 2(e) Update weight vectors
             if trainlabelY(i)==1
                 if trainlabelY(i)~=Tms(i)
                     weight(i)=weight(i)*R^(K-s);
                 else
                     weight(i)=weight(i)*R^(s-K);
                 end
             else
                 if trainlabelY(i)~=Tms(i)
                     weight(i)=weight(i)*R^s;
                 else
                     weight(i)=weight(i)*R^(-s);
                 end
             end
         end

        % step 2(f) Re-normalizeweightvectors.
        Z = sum(weight);
        weight = weight / Z;

    end            
             
end

time1=toc;
tic;
Result = zeros(size(testdata, 1),length(labels));

%step 3 Output Final Classifier
for m = 1 : Max_Iter
    for SNo=1:size(Y,2)
        lrn_out =  testpre{m,SNo};
        for j=1:K
            Result(find(lrn_out==Y(j,SNo)),j)= Result(find(lrn_out==Y(j,SNo)),j)+B(m,SNo)*lrn_out(find(lrn_out==Y(j,SNo)));
        end
    end
end

[max_a,ResultR]=max(Result,[],2);
ResultR0=ResultR;
for j=1:length(labels)
    ResultR0(find(ResultR==j))= labels(j);
end      
time2=toc;
