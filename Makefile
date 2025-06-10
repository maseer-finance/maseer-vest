all        :; forge build
build      :; forge clean && forge build
.PHONY: test
test       :; ./scripts/forge_test.sh --v=$(v) --mt=$(mt) --mc=$(mc)
gas        :; ./scripts/forge_test.sh --v=$(v) --mt=$(mt) --mc=$(mc) gas-report
coverage   :; forge coverage --fork-url=${ETH_RPC_URL}
gen-report :; forge coverage --fork-url=${ETH_RPC_URL} --report lcov && genhtml lcov.info --output-directory docs/coverage-report
clean      :; forge clean

# Deployment
dry-run         :; make build && forge script script/MaseerOne.s.sol --rpc-url ${ETH_RPC_URL} -vvvv --keystore ${ETH_KEYSTORE} --priority-gas-price ${ETH_PRIO_FEE} --base-fee ${ETH_GAS_PRICE}
deploy          :; make build && forge script script/MaseerOne.s.sol --verify --slow --broadcast --rpc-url ${ETH_RPC_URL} -vvvv --keystore ${ETH_KEYSTORE} --priority-gas-price ${ETH_PRIO_FEE} --base-fee ${ETH_GAS_PRICE}
dry-run-sepolia :; make build && forge script --chain sepolia script/MaseerOne.s.sol --rpc-url ${SEPOLIA_RPC_URL} -vvvv --keystore ${ETH_KEYSTORE} --priority-gas-price ${ETH_PRIO_FEE} --base-fee ${ETH_GAS_PRICE}
deploy-sepolia  :; make build && forge script --chain sepolia script/MaseerOne.s.sol --verify --slow --broadcast --rpc-url ${SEPOLIA_RPC_URL} -vvvv --keystore ${ETH_KEYSTORE} --priority-gas-price ${ETH_PRIO_FEE} --base-fee ${ETH_GAS_PRICE}
