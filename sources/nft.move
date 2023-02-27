address nan_tan {
  module NanTan {
    use sui::url::{Self, Url};
    use std::string;
    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::test_scenario;

    /// ===== Resources =====
    struct NanTanNFT has key, store {
            id: UID,
            /// Name for the NanTanNFT
            name: string::String,
            /// Description of the NanTanNFT
            description: string::String,
            /// URL for the NanTanNFT
            url: Url,
            /// Creator of the NanTanNFT
            creator: address
    }
    struct NanTanNFTCollection has key, store {
        id: UID,
        /// Name for the NanTanNFT
        creator:address,
        /// How many NanTanNFT has created
        nft_created:u64,
        /// Total Supply of the NanTanNFT
        supply:u64
    }

    /// Constant
    const MAX_SUPPLY: u64 = 500;
    const TooManyNfts: u64 = 0;


    // ===== Events =====

    struct Init has copy, drop {
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        supply: u64,
    }

    struct NFTMinted has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        name: string::String,
    }

    struct NFTBurned has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        burner: address,
    }

    struct NFTTransfered has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The from address of the NFT
        from: address,
        // The to address of the NFT
        to: address
    }

    // ===== Init functions =====
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let admin = NanTanNFTCollection {
            id: object::new(ctx),
            creator: sender,
            supply: MAX_SUPPLY,
            nft_created: 0,
        };
        // transfer the forge object to the module/package publisher
        // (presumably the game admin)
        transfer::transfer(admin, tx_context::sender(ctx));

        event::emit(Init {
            creator: sender,
            supply: MAX_SUPPLY,
        });
    }

    public fun nft_created(self: &NanTanNFTCollection): u64 {
        self.nft_created
    }
    public fun nft_supply(self: &NanTanNFTCollection): u64 {
        self.supply
    }

    #[test]
    public fun test_module_init() {
        
        // create test address representing game admin
        let admin = @0xBABE;

        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };
        // second transaction to check if the forge has been created
        // and has initial value of zero swords created
        test_scenario::next_tx(scenario, admin);
        {
            // extract the nftCollection object
            let nftCollection = test_scenario::take_from_sender<NanTanNFTCollection>(scenario);
            // verify number of created swords
            assert!(nft_created(&nftCollection) == 0, 1);
            assert!(nft_supply(&nftCollection) == MAX_SUPPLY,1);
            // return the Forge object to the object pool
            test_scenario::return_to_sender(scenario, nftCollection);
        };
        test_scenario::end(scenario_val);
    }


    // ===== Public view functions =====

    /// Get the NFT's `name`
    public fun name(nft: &NanTanNFT): &string::String {
        &nft.name
    }

    /// Get the NFT's `description`
    public fun description(nft: &NanTanNFT): &string::String {
        &nft.description
    }

    /// Get the NFT's `url`
    public fun url(nft: &NanTanNFT): &Url {
        &nft.url
    }

    // ===== Entrypoints =====

    /// Create a new devnet_nft
    public entry fun mint_to_sender(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        nanTanCollection: &mut NanTanNFTCollection,
        ctx: &mut TxContext
    ) {
        // check nft_created <= supply
        assert!(nanTanCollection.nft_created < nanTanCollection.supply,TooManyNfts);

        let sender = tx_context::sender(ctx);
        let nft = NanTanNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url),
            creator: nanTanCollection.creator
        };

        event::emit(NFTMinted {
            object_id: object::id(&nft),
            creator: sender,
            name: nft.name,
        });

        transfer::transfer(nft, sender);
        nanTanCollection.nft_created = nanTanCollection.nft_created + 1;
    }

    #[test]
    public fun test_nft_create() {

        let ctx = &mut tx_context::dummy();
        let admin = @0xBABE;

        let nft = NanTanNFT {
            id: object::new(ctx),
            name: string::utf8(b"TEST"),
            description: string::utf8(b"Description"),
            url: url::new_unsafe_from_bytes(b"http://move.com"),
            creator: admin
        };

        assert!(name(&nft) == &string::utf8(b"TEST"), 1);
        assert!(description(&nft) == &string::utf8(b"Description"), 1);

        let dummy_address = @0xCAFE;
        transfer::transfer(nft, dummy_address);
    }

    #[test]
    public fun test_mint_to_sender() {

        let admin = @0xBABE;
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, admin);
        {
          
            let nft_collection = test_scenario::take_from_sender<NanTanNFTCollection>(scenario);

            assert!(nft_created(&nft_collection) == 0, 1);
            assert!(nft_supply(&nft_collection) == MAX_SUPPLY,1);
            test_scenario::return_to_sender(scenario, nft_collection);
        };

        let nft_minter = @0xAABB;
        test_scenario::next_tx(scenario, nft_minter);
        {
            let nftCollection = test_scenario::take_from_address<NanTanNFTCollection>(scenario,admin);
            let name = b"NanTanNFT";
            let description = b"NanTanNFTDescription";
            let url = b"http://nantannft.com";
            let ctx = test_scenario::ctx(scenario);

            mint_to_sender(name,description,url,&mut nftCollection,ctx);
            
            assert!(nft_created(&nftCollection) == 1, 1);
            assert!(nft_supply(&nftCollection) == MAX_SUPPLY,1);
            
            test_scenario::return_to_address(admin,nftCollection);
        };


        let watcher = @0xBBCC;
        test_scenario::next_tx(scenario, watcher);
        {
            let nft = test_scenario::take_from_address<NanTanNFT>(scenario,nft_minter);
            let name = b"NanTanNFT";
            let description = b"NanTanNFTDescription";
         
            assert!(name(&nft) == &string::utf8(name),1);
            assert!(description(&nft) == &string::utf8(description), 1);
         
            test_scenario::return_to_address(nft_minter, nft);
        };

        test_scenario::end(scenario_val);
        
    }

    /// Transfer `nft` to `recipient`
    public entry fun transfer(
        nft: NanTanNFT, recipient: address, _: &mut TxContext
    ) {
        transfer::transfer(nft, recipient);
    }

    /// Update the `description` of `nft` to `new_description`
    public entry fun update_description(
        nft: &mut NanTanNFT,
        new_description: vector<u8>,
        nanTanCollection: &NanTanNFTCollection,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == nanTanCollection.creator, 0);
        nft.description = string::utf8(new_description)
    }

    #[test]
    public fun test_update_description() {
        let admin = @0xAAAA;
        let nft_minter = @0xAAAB;
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        {
            init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, admin);
        {
            let nft_collection = test_scenario::take_from_sender<NanTanNFTCollection>(scenario);
            assert!(nft_created(&nft_collection) == 0, 1);
            assert!(nft_supply(&nft_collection) == MAX_SUPPLY,1);
            test_scenario::return_to_sender(scenario, nft_collection);
        };
 
        test_scenario::next_tx(scenario, nft_minter);
        {
            let nft_collection = test_scenario::take_from_address<NanTanNFTCollection>(scenario,admin);
            let name = b"NanTanNFT";
            let description = b"NanTanNFTDescription";
            let url = b"http://nantannft.com";
            let ctx = test_scenario::ctx(scenario);
            mint_to_sender(name,description,url,&mut nft_collection,ctx);
            assert!(nft_created(&nft_collection) == 1, 1);
            assert!(nft_supply(&nft_collection) == MAX_SUPPLY,1);
            test_scenario::return_to_address(admin,nft_collection);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let nft_collection = test_scenario::take_from_sender<NanTanNFTCollection>(scenario);
            let nft = test_scenario::take_from_address<NanTanNFT>(scenario,nft_minter);
            let description = b"newDescription";
            let ctx = test_scenario::ctx(scenario);
            update_description(&mut nft,description,&nft_collection,ctx);
            assert!(description(&nft) ==  &string::utf8(description), 1);
            test_scenario::return_to_sender(scenario,nft_collection);
            test_scenario::return_to_address(nft_minter,nft);
        };

        test_scenario::end(scenario_val);
    }

    /// Permanently delete `nft`
   public entry fun burn(nft: NanTanNFT, nft_collection: &NanTanNFTCollection, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == nft_collection.creator, 0);
        // Is sender nft owner?
        event::emit(NFTBurned {
            object_id: object::id(&nft),
            burner: tx_context::sender(ctx)
        });
        let NanTanNFT { id, name: _, description: _, url: _, creator: _ } = nft;
        object::delete(id);
    }

    #[test]
    public fun test_burn() {
        let admin = @0xAAAA;
        let nft_minter = @0xAAAB;
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        {
            init(test_scenario::ctx(scenario));
        };
       
        test_scenario::next_tx(scenario, admin);
        {
            // extract the nftCollection object
            let nft_collection = test_scenario::take_from_sender<NanTanNFTCollection>(scenario);
            // verify number of created swords
            assert!(nft_created(&nft_collection) == 0, 1);
            assert!(nft_supply(&nft_collection) == MAX_SUPPLY,1);
            // return the Forge object to the object pool
            test_scenario::return_to_sender(scenario, nft_collection);
        };
 
        test_scenario::next_tx(scenario, nft_minter);
        {
           
            let nft_collection = test_scenario::take_from_address<NanTanNFTCollection>(scenario,admin);
            let name = b"NanTanNFT";
            let description = b"NanTanNFTDescription";
            let url = b"http://nantannft.com";
            let ctx = test_scenario::ctx(scenario);
            mint_to_sender(name,description,url,&mut nft_collection,ctx);
            assert!(nft_created(&nft_collection) == 1, 1);
            assert!(nft_supply(&nft_collection) == MAX_SUPPLY,1);
            test_scenario::return_to_address(admin,nft_collection);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let nft_collection = test_scenario::take_from_sender<NanTanNFTCollection>(scenario);
            let nft = test_scenario::take_from_address<NanTanNFT>(scenario,nft_minter);
            let ctx = test_scenario::ctx(scenario);
            burn(nft,&nft_collection,ctx);
            test_scenario::return_to_sender(scenario,nft_collection);
        };

        test_scenario::end(scenario_val);
    }
  }

}
