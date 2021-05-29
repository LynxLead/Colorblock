import React, { useState } from 'react';
import PropTypes from 'prop-types';
import { connect } from 'react-redux';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import * as fa from '@fortawesome/free-solid-svg-icons';

import { switchWalletModal } from '../../store/actions/actionCreator';
import { contractModules, getSignedCmd } from '../../utils/sign';
import { serverUrl } from '../../config';

const Header = (props) => {
  const { wallet, switchWalletModal } = props;
  const [isUserPopupOpen, setIsUserPopupOpen] = useState(false);

  const onLogin = async () => {
    const account = wallet.address;
    const cmd = {
      code: `(${contractModules.colorblock}.validate-guard "${account}")`,
      caps: [],
      sender: account,
      signingPubKey: account,
      gasLimit: 0
    };
    const signedCmd = await getSignedCmd(cmd, {
      account
    });
    console.log(signedCmd);
    const result = await fetch(`${serverUrl}/login`, signedCmd).then(res => res.json());
    console.log(result);
    return result;
  };

  return (
    <div data-role='header page'>
      <div data-role='non-fixed part taking space' className='h-16'>
      </div>
      <div data-role='fixed header' className='w-full h-16 fixed top-0 left-0 px-12 bg-white z-50 text-sm'>
        <div data-role='fixed header container' className='h-full flex justify-between border-b border-gray-200'>
          <div data-role='left flex part' className='h-full flex'>
            <div data-role='logo' className='mx-5 h-full py-3'>
              <a href='/'><img src='/img/colorblock_logo.svg' className='h-full' alt='logo' /></a>
            </div>
            <div data-role='search bar' className='w-120 my-3 flex items-center bg-gray-50 border rounded-lg border-white hover-pink'>
              <div className='mx-2 text-gray-300'>
                <FontAwesomeIcon icon={fa.faSearch} />
              </div>
              <input
                className='w-full px-0.5 bg-gray-50 placeholder-gray-400 placeholder-opacity-75'
                placeholder='Search collections, collectibles, and artists'
              />
            </div>
            <div data-role='nav bar' className='ml-7'>
              <ul className='h-full flex items-center space-x-7'>
                <li><a href='/market'>Market</a></li>
                <li><a href='/market'>Collections</a></li>
                <li><a href='/create'>Create</a></li>
                <li><a href='/market'>Token</a></li>
              </ul>
            </div>
          </div>
          <div data-role='right flex part' className='flex items-center space-x-8'>
            <span className='whitespace-nowrap'>My Profile</span>
            <div className='relative'>
              <img src='/img/profile_picture.svg' className='w-7 h-7 mx-2' alt='profile' onClick={ () => setIsUserPopupOpen(!isUserPopupOpen) } />
              <div 
                data-role='account popup' 
                className='absolute top-12 -left-10 w-32 h-32 mt-2 bg-white border border-gray-300 rounded'
                hidden={!isUserPopupOpen}  
              >
                <button className='w-full rounded py-2 border-b' onClick={ () => onLogin() }>Login</button>
              </div>
            </div>
            <button
              className='py-2 px-4 bg-cb-pink border rounded-lg border-white text-white'
              onClick={ () => switchWalletModal() }
            >
              { wallet.address ?
                `${wallet.address.slice(0, 3)}**${wallet.address.slice(-4)}` :
                'Connect'
              }
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

Header.propTypes = {
  wallet: PropTypes.object.isRequired
};

const mapStateToProps = state => ({
  wallet: state.wallet
});

const mapDispatchToProps = dispatch => ({
  switchWalletModal: () => dispatch(switchWalletModal()),
});

export default connect(mapStateToProps, mapDispatchToProps)(Header);

