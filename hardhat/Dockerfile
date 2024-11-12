FROM node:20-alpine

COPY . /hardhat
WORKDIR /hardhat

RUN npm install --save-dev --verbose hardhat
CMD ["npx", "hardhat", "node"]
