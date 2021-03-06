function [f,g] = MLPclassificationLoss_combine7(w,X,y,nHidden,nLabels,lambda)

[nInstances,nVars] = size(X);

% Form Weights
inputWeights = reshape(w(1:nVars*nHidden(1)),nVars,nHidden(1));
offset = nVars*nHidden(1);
for h = 2:length(nHidden)
  hiddenWeights{h-1} = reshape(w(offset+1:offset+nHidden(h-1)*nHidden(h)),nHidden(h-1),nHidden(h));
  offset = offset+nHidden(h-1)*nHidden(h);
end
outputWeights = w(offset+1:offset+nHidden(end)*nLabels);
outputWeights = reshape(outputWeights,nHidden(end),nLabels);

f = 0;
if nargout > 1
    gInput = zeros(size(inputWeights));
    for h = 2:length(nHidden)
       gHidden{h-1} = zeros(size(hiddenWeights{h-1})); 
    end
    gOutput = zeros(size(outputWeights));
end

% Compute Output
for i = 1:nInstances
    % forward process
    % input layer
    ip{1} = X(i,:)*inputWeights;
    fp{1} = tanh(ip{1});
    
    % dropout
    rd = rand(1,nHidden(1))<0.5;
    fp{1} = fp{1}.*rd;
    
    % bias term
    fp{1}(end) = 1;
    % hidden layers
    for h = 2:length(nHidden)
        ip{h} = fp{h-1}*hiddenWeights{h-1};
        fp{h} = tanh(ip{h});
        
        % dropout
        rd = rand(1,nHidden(h))<0.5;
        fp{h} = fp{h}.*rd;
        
        % bias term
        fp{h}(end) = 1;
    end
    % output value
    yhat = fp{end}*outputWeights;
    % softmax layer
    yhat = softmax(yhat')';
    
    % transform into a 0-1 encoding
    y01 = y(i,:)>0;
    
    % the nagetive log of the probability
    relativeErr = -y01'*log(yhat);
    f = f + relativeErr;
    
    if nargout > 1
        % the differential of the objective function w.r.t outputweights
        err = -(y01 - yhat);
        
        % Output Weights' gradient
        gOutput = gOutput + fp{end}' * err;

        if length(nHidden) > 1
            % Last Layer of Hidden Weights
            clear backprop
            for c = 1:nLabels
                backprop(c,:) = err(c)*(sech(ip{end}).^2.*outputWeights(:,c)');
                gHidden{end} = gHidden{end} + fp{end-1}'*backprop(c,:);
            end
            backprop = sum(backprop,1);

            % Other Hidden Layers
            for h = length(nHidden)-2:-1:1
                backprop = (backprop*hiddenWeights{h+1}').*sech(ip{h+1}).^2;
                gHidden{h} = gHidden{h} + fp{h}'*backprop;
            end

            % Input Weights
            backprop = (backprop*hiddenWeights{1}').*sech(ip{1}).^2;
            gInput = gInput + X(i,:)'*backprop;
        else
            % Input Weights
            gInput = X(i,:)' * (sech(ip{end}).^2.*(err * outputWeights'));
        end

    end
    
end

% Put Gradient into vector
if nargout > 1
    g = zeros(size(w));
    g(1:nVars*nHidden(1)) = gInput(:);
    offset = nVars*nHidden(1);
    for h = 2:length(nHidden)
        g(offset+1:offset+nHidden(h-1)*nHidden(h)) = gHidden{h-1};
        offset = offset+nHidden(h-1)*nHidden(h);
    end
    g(offset+1:offset+nHidden(end)*nLabels) = gOutput(:);
end

% weight decay
rdd = abs(g)>0;
g = g + lambda * w.*rdd; % when combine with dropout
