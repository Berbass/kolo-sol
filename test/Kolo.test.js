// javascript
const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("KOLO", function () {
    let kolo;
    let mockEurc;
    let owner, alice, bob, eurcOwner;

    beforeEach(async function () {
        [owner, alice, bob, eurcOwner] = await ethers.getSigners();
        const MockERC20 = await ethers.getContractFactory("MockEURc", eurcOwner);
        mockEurc = await MockERC20.deploy(ethers.parseUnits("100", 6)); // initial EURc supply to eurcOwner

        // Transfer some EURc to the KOLO owner to simulate reserves
        await mockEurc.connect(eurcOwner).transfer(owner.address, ethers.parseUnits("20", 6));

        const KOLO = await ethers.getContractFactory("KOLO", owner);
        kolo = await KOLO.deploy(mockEurc, owner.address);
    });

    it("decimals()", async function () {
        expect(await kolo.decimals()).to.equal(6);
    });

    it("owner can mint", async function () {
        const amount = 1_000;
        await kolo.connect(owner).mint(alice.address, amount);
        expect(await kolo.balanceOf(alice.address)).to.equal(amount);
    });

    it("non-owner cannot mint", async function () {
        await expect(kolo.connect(alice).mint(alice.address, 1)).to.be.revertedWithCustomError(
            kolo,
            "Unauthorized"
        );
    });

    it("burn when not paused", async function () {
        const amount = 500;
        await kolo.connect(owner).mint(alice.address, amount);
        await kolo.connect(alice).burn(200);
        expect(await kolo.balanceOf(alice.address)).to.equal(amount - 200);
    });

    it("burn reverts when paused", async function () {
        const amount = 300;
        await kolo.connect(owner).mint(alice.address, amount);
        await kolo.connect(owner).pause();
        await expect(kolo.connect(alice).burn(100)).to.be.revertedWithCustomError(
            kolo,
            "ContractPaused"
        );
    });

    it("pause/unpause access control", async function () {
        await expect(kolo.connect(alice).pause()).to.be.revertedWithCustomError(
            kolo,
            "Unauthorized"
        );

        await kolo.connect(owner).pause();
        expect(await kolo.paused()).to.equal(true);

        await kolo.connect(owner).unpause();
        expect(await kolo.paused()).to.equal(false);
    });

    it("transfers blocked when paused", async function () {
        const amount = 1_000;
        await kolo.connect(owner).mint(owner.address, amount);

        await kolo.connect(owner).transfer(alice.address, 100);
        expect(await kolo.balanceOf(alice.address)).to.equal(100);

        await kolo.connect(owner).pause();

        await expect(kolo.connect(owner).transfer(bob.address, 1)).to.be.revertedWithCustomError(
            kolo,
            "ContractPaused"
        );
    });

    it("checks convert helpers", async function () {
        // contract constants: EURC_PER_KOL = 1525, EUR_KOL_SCALE = 1000
        const eurc = 1525;
        const koloAmount = await kolo.convertFromEurc(eurc);
        expect(koloAmount).to.equal(1000);

        const eurcBack = await kolo.convertToEurc(koloAmount);
        expect(eurcBack).to.equal(1525);

        const eurc2 = 7625; // 5 * 1525
        expect(await kolo.convertFromEurc(eurc2)).to.equal(5000); // 5 * 1000
    });

    it("checks mint reverts when exceed EURc reserve", async function () {
        const maxKlo = await kolo.convertFromEurc(ethers.parseUnits("20", 6));

        const amount = maxKlo + ethers.parseUnits("0.000001", 6); // exceeds mocked reserve by smallest unit
        await expect(kolo.connect(owner).mint(owner.address, amount)).to.be.revertedWithCustomError(
            kolo,
            "InsufficientReserve"
        );
    });
});
