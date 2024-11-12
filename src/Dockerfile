FROM python:3.10.15

COPY training/requirements.txt /app/
COPY training/strategy/de_fed.py /app/
COPY training/pyproject.toml /app/
COPY training/xgboost_comprehensive /app/xgboost_comprehensive/
COPY contract/abi.json /app/xgboost_comprehensive/

WORKDIR /app

RUN pip install -r requirements.txt
RUN pip install -U "flwr[simulation]"

ENTRYPOINT ["flwr", "run", "."]
