// SPDX-License-Identifier: MIT
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const PropertyPulseTokenModule = buildModule("PropertyPulseTokenModule", (m: any) => {
  const propertyPulseToken = m.contract("PropertyPulseToken");

  return { propertyPulseToken };
});

module.exports = PropertyPulseTokenModule;