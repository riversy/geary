/* Copyright 2012-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Geary.ImapEngine.MoveEmailRevoke : Geary.ImapEngine.SendReplayOperation {
    private MinimalFolder engine;
    private Gee.List<ImapDB.EmailIdentifier> to_revoke = new Gee.ArrayList<ImapDB.EmailIdentifier>();
    private Cancellable? cancellable;
    
    public MoveEmailRevoke(MinimalFolder engine, Gee.Collection<ImapDB.EmailIdentifier> to_revoke,
        Cancellable? cancellable) {
        base.only_local("MoveEmailRevoke", OnError.RETRY);
        
        this.engine = engine;
        
        this.to_revoke.add_all(to_revoke);
        this.cancellable = cancellable;
    }
    
    public override void notify_remote_removed_ids(Gee.Collection<ImapDB.EmailIdentifier> ids) {
        to_revoke.remove_all(ids);
    }
    
    public override async ReplayOperation.Status replay_local_async() throws Error {
        if (to_revoke.size == 0)
            return ReplayOperation.Status.COMPLETED;
        
        yield engine.local_folder.mark_removed_async(to_revoke, false, cancellable);
        
        int count = engine.get_remote_counts(null, null);
        
        engine.replay_notify_email_inserted(to_revoke);
        engine.replay_notify_email_count_changed(count + to_revoke.size,
            Geary.Folder.CountChangeReason.INSERTED);
        
        return ReplayOperation.Status.COMPLETED;
    }
    
    public override void get_ids_to_be_remote_removed(Gee.Collection<ImapDB.EmailIdentifier> ids) {
    }
    
    public override async ReplayOperation.Status replay_remote_async() throws Error {
        return ReplayOperation.Status.COMPLETED;
    }
    
    public override async void backout_local_async() throws Error {
    }
    
    public override string describe_state() {
        return "%d email IDs".printf(to_revoke.size);
    }
}

