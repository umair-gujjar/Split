import { RECEIVE_FRIEND, RECEIVE_ALL_FRIENDS, RECEIVE_ERRORS } from '../actions/friendship_actions.js';
import merge from 'lodash/merge';

const initialState = {
  // 2: {
  //   id: 2,
  //   username: "Brian",
  //   email: "brian@brian.com"
  // },
  // 3: {
  //   id: 3,
  //   username: "Nick",
  //   email: "nick@nick.com"
  // },
  // 4: {
  //   id:4,
  //   username: "Matt",
  //   email: "matt@matt.com"
  // }
};

const friendshipReducer = (state = initialState, action) => {
  let newState = merge({}, state);
  Object.freeze(state);
  switch(action.type) {
    case RECEIVE_FRIEND:
      newState = {
        [action.friend.id]:action.friend,
        errors: []
      };
      return newState;
    case RECEIVE_ALL_FRIENDS:
      return merge(newState, action.friends);
    case RECEIVE_ERRORS:
      newState = {
        errors: action.errors
      };
      return newState;
    default:
      return state;
  }
};

export default friendshipReducer;