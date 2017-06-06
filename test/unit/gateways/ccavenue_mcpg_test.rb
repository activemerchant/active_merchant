require 'test_helper'

class CcavenueMcpgTest < Test::Unit::TestCase
  def setup
    @gateway = CcavenueMcpgGateway.new(
	:merchant_id=> '3577',
	:working_key=> '34E3E11B09C6407CA50EC1E2C52819E0',
	:access_code=> 'AVRX00BL19AW02XRWA'
	)
	
    @credit_card = credit_card
    @amount = 100

    @options = {        		
        :order_id=> '24891549',        
        :email=> 'john@example.com',
        :billing_address=> {
          :name=> 'John Snow',
          :address1=> '111 Road',
          :address2=> 'Suite 111',
          :city=> 'Somewhere',
          :state=> 'XX',
          :country=> 'India',
          :zip=> '12345',
          :phone=> '12223334444'
        },
        :shipping_address=> {
          :name=> 'John Snow',
          :address1=> '222 Street',
          :address2=> 'Suite 222',
          :city=> 'Anyplace',
          :state=> 'YY',
          :country=> 'India',
          :zip=> '12346',
          :phone=> '1234567898'
        }
		}
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '204000161274', response.authorization
	assert_equal 'Your order is Successful', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Your order is Unsuccessful", response.message
  end

 
  def successful_purchase_response
   '1bf320558c778969858aa0d3824faf424d94cb62a18de13a9f565e886d9318c5ecb55777f801b55a63232db40e4c897af04a921966887198edddbe6cfcf31bef0c93ef35ae1dd47f360dd073e87b5faded36202c0b34a8ee5b8f01ad9d9fd1ac2a9a7ee2255dc4c0a79d3121aae7ff5484cb05cd8ba7bcff46edbdded92825a2714080a9f463f271f2887bfe39382cd002d73de7b5988e56ee6a29765c5b5109ac7638e494d49d8585540af5833aa120253a5bad384fad3ebc7d2231fc907b9c385e385fe96e4428b756168e6600e2e1f5ba0044dc3b1a6a0db5bf853afb166accb039e8b4652149c79ea380d9a17961ce81aa8681a013146fcb14cf048763341746b9afccbb5c4ddd9ab10a37d39a55ae24d73b5115d7434af671c7608fd9fea52e93b19305e8545ab9b9b0f25811c9354a67a04a1b93553b9170658b8f678baa918d9cf6db9ba83b665c4df325833c4f1202972b8e7100165f685255d43c0c0b42754e851e953f545c1547569e80cc0b49e37591f128b95f654bfc11a6e8f6db5e58aecabade4f82b67160b62e1d67d6f1c24ed42075eb942f23d3a00f2ab46bbdfb4603fc28f83fa93054b9fe9ca1b95952122d1e8f9b52e00090fa116d09a0ab5c8c8288f930283fb370d91be33e9ca797ce5c58d07504e65413acb483fa2b0f92526b2e2c28f9cef03f1736a356acb737e5a9798aee9879ad316f305dc551089c4d0c4b980aababdab148f94065ba44e738a10afbb9e4bc54d624ef2900e4b570fb4e1c88700dc2277f348477d3e1864e6a64a0697eda826c64a818efb373c54e0522674459de94922fdc00e9677b0d5f5315dfbf6d411a5aa6bb97d2d8cda74c97ecd931df69eaee3130cd05c8c64c8735f1125d270d6ff6a5c8e6ba00224ec9b394155ead8948b39e15bc12d52c1b16c4a2e274bcc5b9870ad76a88cb8227708602049965d8887d046bd15917ef813fed29e228041caa181a611728cd8872fefa44292e6ac961c299b832b29086997f5d944fb78db2329de831314895'
  end

  def failed_purchase_response
	'ba89f543c194788ca75118ad39b3bebca105130eb1f6160357b5ae06775c6f11fde960a92e0154b4383ede1b77ea05d0db67dc766b09ec16cd740421dfdc796300826493cfb10dd7114885ec0a009fa0cfe2ab9241c42ff9abbcd6006d1560c15871e04a38ac52f56a7ef918c5c7c336ad39f4289969470a07d9ef90e158352752c550597c7d50c9d9b71959012f0e6c18f4bbeaec70a1a1ef719843d80f48ef13b5f68076e5d4a08d591627833328f7c947845f2030b0dca074d6e5e77526724bee5d451f8a8b53c594bab64ba25df9966ae0eaa781d58216f23799cd33d73575ebded0247895e0f7ebe46b60ee653d75a1d7e89c749b488a2693a8872b194db3438f5ae6f1fc9831298e4a661d35c8e5c0ed365a45b76860d871b24e6a3e8cee2a472b8382b5c0fac3519fc6b623b93d30309aa3e00ad6f9e35b6c45b50b6f374b627bd590cd320c52ceda11da5268acb33e0e400062b6bca4d8917fd2514532db117d1c556f13d5e7d0d09fccdc6a88154c8dc4b08579e0f4904ed72858dfeceb5f7e7febaa7c40acf78718ebe685991343770be41a719603daf2d68f8db420f678bd9104d85ff087550ed04ddad059ce9719824528d9b365fa4f0e1ee3a300fbc1660aeec8bc1588370f4b3159630923921232c2114bffaa6268ecc4d41e74da07b4cae04f970d3baca69b69e4922685c6e71855aac74153ad9ac3fc311496d75a855c7212d0432fd05442c023ffd74a096f82c9a22e87b889a779c31113a631f44e1be43cf34e7b313f06c2eb166d2d9719a79927e88c2ea9ec321486da54e15bb6d16bae445c686722c8ce61ca1857a6d84f2ccc69e48de0c2645b487c3ea90fc592e6acdb0451996fc14a4213cb43beb69ed185e097ee4dfbdb302de234b6365782ea79cbc01493551d676160ee587b8deabfedffda01f62f2d14c3b378074796ef27d3195511f87c00f2679f4e474c58dbcb38259b8261d077e4c2d0620df834d4e5e2322793fdb4329d23e28dc70e7f9ca7bcd433ea55b51c6b6d0d'
  end

end
