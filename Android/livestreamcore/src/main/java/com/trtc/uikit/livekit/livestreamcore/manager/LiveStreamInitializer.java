package com.trtc.uikit.livekit.livestreamcore.manager;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.tencent.cloud.tuikit.engine.common.TUICommonDefine;
import com.tencent.cloud.tuikit.engine.room.TUIRoomDefine;
import com.tencent.cloud.tuikit.engine.room.TUIRoomEngine;
import com.tencent.qcloud.tuicore.TUIConfig;
import com.tencent.qcloud.tuicore.TUIConstants;
import com.tencent.qcloud.tuicore.TUICore;
import com.tencent.qcloud.tuicore.TUILogin;
import com.tencent.qcloud.tuicore.interfaces.ITUINotification;
import com.trtc.tuikit.common.system.ContextProvider;
import com.trtc.uikit.livekit.livestreamcore.common.utils.Logger;

public final class LiveStreamInitializer extends ContentProvider {

    private final ITUINotification mNotification = (key, subKey, param) -> {
        if (TUIConstants.TUILogin.EVENT_LOGIN_STATE_CHANGED.equals(key)
                && TUIConstants.TUILogin.EVENT_SUB_KEY_USER_LOGIN_SUCCESS.equals(subKey)
                && TUILogin.isUserLogined()) {
            TUIRoomEngine.login(TUIConfig.getAppContext(), TUILogin.getSdkAppId(), TUILogin.getUserId(),
                    TUILogin.getUserSig(), new TUIRoomDefine.ActionCallback() {
                        @Override
                        public void onSuccess() {
                            Logger.info("LiveStreamInitializer login:[Success]");
                        }

                        @Override
                        public void onError(TUICommonDefine.Error error, String message) {
                            Logger.error("LiveStreamInitializer login:[Error:" + error + ",message:" + message
                                    + "]");
                        }
                    });
        }
    };

    @Override
    public boolean onCreate() {
        loginRoomEngine();
        registerEvent();
        return false;
    }

    private void loginRoomEngine() {
        if (TUILogin.isUserLogined()) {
            TUIRoomEngine.login(TUILogin.getAppContext(), TUILogin.getSdkAppId(), TUILogin.getUserId(),
                    TUILogin.getUserSig(), new TUIRoomDefine.ActionCallback() {
                        @Override
                        public void onSuccess() {
                            Logger.info("RoomEngine login:[Success]");
                        }

                        @Override
                        public void onError(TUICommonDefine.Error error, String message) {
                            Logger.error("RoomEngine login : [onError:[error:" + error + ",message:" + message
                                    + "]]");
                        }
                    });
        }
    }

    private void registerEvent() {
        TUICore.registerEvent(TUIConstants.TUILogin.EVENT_LOGIN_STATE_CHANGED,
                TUIConstants.TUILogin.EVENT_SUB_KEY_USER_LOGIN_SUCCESS, mNotification);
        if (getContext() != null) {
            ContextProvider.setApplicationContext(this.getContext().getApplicationContext());
        }
    }

    @Nullable
    @Override
    public Cursor query(@NonNull Uri uri, @Nullable String[] projection, @Nullable String selection,
                        @Nullable String[] selectionArgs, @Nullable String sortOrder) {
        return null;
    }

    @Nullable
    @Override
    public String getType(@NonNull Uri uri) {
        return null;
    }

    @Nullable
    @Override
    public Uri insert(@NonNull Uri uri, @Nullable ContentValues values) {
        return null;
    }

    @Override
    public int delete(@NonNull Uri uri, @Nullable String selection, @Nullable String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(@NonNull Uri uri, @Nullable ContentValues values, @Nullable String selection,
                      @Nullable String[] selectionArgs) {
        return 0;
    }
}
